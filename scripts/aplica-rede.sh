#!/usr/bin/env bash
# Nome: aplica-rede.sh
# Finalidade: Configurar endereços estáticos, rotas e encaminhamento IPv4 do servidor.
# Data: 18/11/2026
# Requisitos: Bash, Ubuntu Server, Netplan e acesso ao config/lab.env.
# Uso: sudo bash scripts/aplica-rede.sh
# Requisito do trabalho atendido: R2.1
# Fonte externa: nenhuma

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly LAB_ENV="${REPO_DIR}/config/lab.env"
readonly NETPLAN_DIR="/etc/netplan"
readonly NETPLAN_FILE="${NETPLAN_DIR}/01-netcfg.yaml"
readonly NETPLAN_TEMPLATE="${REPO_DIR}/infra/netplan/01-netcfg.yaml.tmpl"
readonly SYSCTL_FILE="/etc/sysctl.d/99-saas-forward.conf"

backup_dir=""
rendered_file=""
netplan_changed=false
sysctl_changed=false

# Valida um IPv4 antes de inseri-lo no YAML, evitando gravar uma configuração inválida.
# Parâmetro: endereço IPv4 em notação decimal pontuada.
valid_ipv4() {
    local address="$1"
    local octet
    local -a octets

    [[ "${address}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r -a octets <<< "${address}"
    for octet in "${octets[@]}"; do
        (( 10#${octet} <= 255 )) || return 1
    done
}

# Confere rede e prefixo CIDR para que os endereços de interface gerem rotas coerentes.
# Parâmetro: rede IPv4 seguida de barra e prefixo.
valid_cidr() {
    local value="$1"
    local prefix

    [[ "${value}" == */* ]] || return 1
    valid_ipv4 "${value%/*}" || return 1
    prefix="${value##*/}"
    [[ "${prefix}" =~ ^[0-9]{1,2}$ ]] || return 1
    (( 10#${prefix} >= 1 && 10#${prefix} <= 32 ))
}

# Restaura a configuração anterior se uma etapa falhar após substituir os arquivos.
# Parâmetro: nenhum; preserva o código de saída original do script.
finish() {
    local status=$?
    local -a current_configs=()
    local -a saved_configs=()

    trap - EXIT
    if [[ -n "${rendered_file}" ]]; then
        rm -f -- "${rendered_file}"
    fi

    if (( status != 0 )) && [[ "${netplan_changed}" == true ]]; then
        printf 'Falha ao aplicar a rede. Restaurando os arquivos Netplan de %s.\n' "${backup_dir}" >&2
        shopt -s nullglob
        current_configs=("${NETPLAN_DIR}"/*.yaml "${NETPLAN_DIR}"/*.yml)
        if ((${#current_configs[@]} > 0)); then
            rm -f -- "${current_configs[@]}"
        fi
        saved_configs=("${backup_dir}"/netplan/*.yaml "${backup_dir}"/netplan/*.yml)
        if ((${#saved_configs[@]} > 0)); then
            cp -a -- "${saved_configs[@]}" "${NETPLAN_DIR}/"
            if ! netplan generate || ! netplan apply; then
                printf 'ERRO: a restauração automática do Netplan falhou. Use o console da VM e os backups em %s.\n' "${backup_dir}" >&2
            fi
        else
            printf 'Não havia arquivo Netplan anterior para restaurar. Consulte o backup em %s pelo console da VM.\n' "${backup_dir}" >&2
        fi
    fi

    if (( status != 0 )) && [[ "${sysctl_changed}" == true ]]; then
        printf 'Falha ao aplicar sysctl. Restaurando a configuração anterior.\n' >&2
        if [[ -f "${backup_dir}/99-saas-forward.conf" ]]; then
            cp -a -- "${backup_dir}/99-saas-forward.conf" "${SYSCTL_FILE}"
        else
            rm -f -- "${SYSCTL_FILE}"
        fi
        if ! sysctl --system; then
            printf 'ERRO: não foi possível reaplicar as configurações sysctl anteriores.\n' >&2
        fi
    fi

    exit "${status}"
}

if (( EUID != 0 )); then
    printf 'Execute este script como root, por exemplo: sudo bash scripts/aplica-rede.sh\n' >&2
    exit 1
fi

if [[ ! -r "${LAB_ENV}" || ! -r "${NETPLAN_TEMPLATE}" ]]; then
    printf 'ERRO: não encontrei config/lab.env ou o modelo Netplan no repositório.\n' >&2
    exit 1
fi

# O arquivo é a fonte única de endereços e interfaces; carregá-lo evita duplicar
# valores de rede no script.
source "${LAB_ENV}"

required_vars=(
    IFACE_LAN IFACE_WAN LAN_IP_SERVIDOR LAN_REDE WAN_IP_SERVIDOR WAN_REDE
    WAN_GATEWAY ROTA_ESTATICA_REDE ROTA_ESTATICA_VIA DNS_SERVERS
    NETPLAN_TRY_TIMEOUT IPV4_FORWARD
)
for variable_name in "${required_vars[@]}"; do
    if [[ -z "${!variable_name:-}" || "${!variable_name}" == "DEFINIR" ]]; then
        printf 'ERRO: defina %s em config/lab.env antes de continuar.\n' "${variable_name}" >&2
        exit 1
    fi
done

if [[ ! "${IFACE_LAN}" =~ ^[[:alnum:]_.:-]+$ || ! "${IFACE_WAN}" =~ ^[[:alnum:]_.:-]+$ ]]; then
    printf 'ERRO: IFACE_LAN e IFACE_WAN devem conter nomes de interface válidos.\n' >&2
    exit 1
fi
if [[ "${IFACE_LAN}" == "${IFACE_WAN}" ]]; then
    printf 'ERRO: IFACE_LAN e IFACE_WAN não podem identificar a mesma interface.\n' >&2
    exit 1
fi
if [[ ! -d "/sys/class/net/${IFACE_LAN}" || ! -d "/sys/class/net/${IFACE_WAN}" ]]; then
    printf 'ERRO: confira se IFACE_LAN e IFACE_WAN existem neste servidor.\n' >&2
    exit 1
fi
if ! valid_ipv4 "${LAN_IP_SERVIDOR}" || ! valid_ipv4 "${WAN_IP_SERVIDOR}" || ! valid_ipv4 "${WAN_GATEWAY}" || ! valid_ipv4 "${ROTA_ESTATICA_VIA}"; then
    printf 'ERRO: confira os endereços IPv4 em config/lab.env.\n' >&2
    exit 1
fi
if ! valid_cidr "${LAN_REDE}" || ! valid_cidr "${WAN_REDE}" || ! valid_cidr "${ROTA_ESTATICA_REDE}"; then
    printf 'ERRO: confira as redes CIDR em config/lab.env.\n' >&2
    exit 1
fi
if [[ ! "${NETPLAN_TRY_TIMEOUT}" =~ ^[1-9][0-9]*$ ]]; then
    printf 'ERRO: NETPLAN_TRY_TIMEOUT deve ser um inteiro positivo, em segundos.\n' >&2
    exit 1
fi
if [[ "${IPV4_FORWARD}" != "1" ]]; then
    printf 'ERRO: IPV4_FORWARD deve ser 1 para atender ao roteamento deste laboratório.\n' >&2
    exit 1
fi

# A lista é escrita em formato separado por vírgulas porque o modelo Netplan
# insere cada endereço DNS diretamente como um item YAML.
IFS=',' read -r -a dns_servers <<< "${DNS_SERVERS}"
if ((${#dns_servers[@]} == 0)); then
    printf 'ERRO: DNS_SERVERS precisa conter ao menos um endereço IPv4.\n' >&2
    exit 1
fi
for dns_server in "${dns_servers[@]}"; do
    dns_server="${dns_server//[[:space:]]/}"
    if ! valid_ipv4 "${dns_server}"; then
        printf 'ERRO: DNS_SERVERS deve conter endereços IPv4 separados por vírgulas.\n' >&2
        exit 1
    fi
done

if ! command -v netplan >/dev/null 2>&1 || ! command -v sysctl >/dev/null 2>&1; then
    printf 'ERRO: netplan e sysctl precisam estar instalados no servidor.\n' >&2
    exit 1
fi

# gettext-base fornece envsubst; instalá-lo apenas quando necessário mantém
# a implantação repetível sem adicionar dependências ao repositório.
if ! command -v envsubst >/dev/null 2>&1; then
    if ! command -v apt-get >/dev/null 2>&1; then
        printf 'ERRO: envsubst não existe e apt-get não está disponível para instalá-lo.\n' >&2
        exit 1
    fi
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y gettext-base
fi

LAN_PREFIX="${LAN_REDE##*/}"
WAN_PREFIX="${WAN_REDE##*/}"
export IFACE_LAN IFACE_WAN LAN_IP_SERVIDOR WAN_IP_SERVIDOR WAN_GATEWAY
export ROTA_ESTATICA_REDE ROTA_ESTATICA_VIA DNS_SERVERS LAN_PREFIX WAN_PREFIX

mkdir -p -- /var/backups
backup_dir="$(mktemp -d /var/backups/saas-network.XXXXXX)"
chmod 700 "${backup_dir}"
if [[ -d "${NETPLAN_DIR}" ]]; then
    cp -a -- "${NETPLAN_DIR}" "${backup_dir}/netplan"
else
    mkdir -p -- "${NETPLAN_DIR}" "${backup_dir}/netplan"
fi
if [[ -f "${SYSCTL_FILE}" ]]; then
    cp -a -- "${SYSCTL_FILE}" "${backup_dir}/99-saas-forward.conf"
fi
rendered_file="$(mktemp)"
trap finish EXIT
envsubst '${IFACE_LAN} ${IFACE_WAN} ${LAN_IP_SERVIDOR} ${LAN_PREFIX} ${WAN_IP_SERVIDOR} ${WAN_PREFIX} ${ROTA_ESTATICA_REDE} ${ROTA_ESTATICA_VIA} ${WAN_GATEWAY} ${DNS_SERVERS}' \
    < "${NETPLAN_TEMPLATE}" > "${rendered_file}"

# Netplan combina todos os YAML ativos. Retirar os anteriores só depois do
# backup evita configurações concorrentes, como a criada pelo instalador.
netplan_changed=true
shopt -s nullglob
old_configs=("${NETPLAN_DIR}"/*.yaml "${NETPLAN_DIR}"/*.yml)
if ((${#old_configs[@]} > 0)); then
    rm -f -- "${old_configs[@]}"
fi
install -o root -g root -m 600 "${rendered_file}" "${NETPLAN_FILE}"
netplan generate
printf 'Confirme a configuração no console da VM dentro de %s segundos.\n' "${NETPLAN_TRY_TIMEOUT}"
netplan try --timeout "${NETPLAN_TRY_TIMEOUT}"
netplan_changed=false

# O encaminhamento permite ao servidor rotear entre WAN e LAN; o arquivo
# separado em sysctl.d preserva a opção após reinicializações.
sysctl_changed=true
install -o root -g root -m 644 /dev/null "${SYSCTL_FILE}"
printf 'net.ipv4.ip_forward=%s\n' "${IPV4_FORWARD}" > "${SYSCTL_FILE}"
sysctl --system
if [[ "$(sysctl -n net.ipv4.ip_forward)" != "${IPV4_FORWARD}" ]]; then
    printf 'ERRO: o encaminhamento IPv4 não ficou habilitado.\n' >&2
    exit 1
fi
sysctl_changed=false

printf '\nEndereços configurados:\n'
ip -br addr
printf '\nTabela de rotas:\n'
ip route
printf '\nBackup da configuração anterior: %s\n' "${backup_dir}"
