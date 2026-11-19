#!/usr/bin/env bash
# Nome: firewall.sh
# Finalidade: Aplicar, verificar, limpar e testar as regras do firewall da plataforma SaaS.
# Autor: DEFINIR
# Data: 19/11/2026
# Requisitos: Bash, Ubuntu Server, iptables, iptables-save, iptables-restore e systemd.
# Uso: sudo bash scripts/firewall.sh [--aplicar|--status|--limpar|--liberar-scan|--teste SEGUNDOS [--confirmar]]
# Requisito do trabalho atendido: R2.2, R2.3 e R2.4
# Fonte externa: nenhuma

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly LAB_ENV="${REPO_DIR}/config/lab.env"
readonly UNIT_NAME="saas-firewall.service"
readonly UNIT_SOURCE="${REPO_DIR}/infra/systemd/${UNIT_NAME}"
readonly UNIT_DEST="/etc/systemd/system/${UNIT_NAME}"

# Variáveis lidas de lab.env com valores vazios até serem definidos.
LAN_REDE=""
PORTA_SSH=""
PORTA_HTTP=""
PORTA_HTTPS=""
PORTA_DB=""
IFACE_WAN=""
IFACE_LAN=""
ARQUIVO_REGRAS_IPTABLES=""
DEPLOY_ORIGEM=""
SCAN_SEGUNDOS=""
SCAN_TENTATIVAS=""
SSH_SEGUNDOS=""
SSH_MAX_CONEXOES=""
HTTP_LIMIT=""
HTTP_BURST=""
HTTPS_LIMIT=""
HTTPS_BURST=""
ICMP_LIMIT=""
ICMP_BURST=""
LOG_LIMIT=""
LOG_BURST=""

# A validação evita aplicar regras com intervalos ou portas inválidos.
# Parâmetro: expressão esperada como inteiro positivo.
validar_inteiro() {
    local valor="$1"
    [[ "${valor}" =~ ^[1-9][0-9]*$ ]]
}

# A validação impede que uma fonte ou rede CIDR contenha texto inesperado.
# Parâmetro: rede IPv4 no formato endereço/prefixo ou vazio.
validar_origem() {
    local origem="$1"
    local endereco
    local prefixo

    [[ -z "${origem}" ]] && return 0
    if [[ "${origem}" == */* ]]; then
        endereco="${origem%/*}"
        prefixo="${origem##*/}"
        [[ "${prefixo}" =~ ^([1-9]|[12][0-9]|3[0-2])$ ]] || return 1
    else
        endereco="${origem}"
    fi
    validar_ipv4 "${endereco}"
}

# Confere os quatro octetos antes de usar um endereço em uma regra.
# Parâmetro: endereço IPv4 em notação decimal pontuada.
validar_ipv4() {
    local address="$1"
    local octeto
    local -a octetos

    [[ "${address}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r -a octetos <<< "${address}"
    for octeto in "${octetos[@]}"; do
        (( 10#${octeto} <= 255 )) || return 1
    done
}

# Confere redes CIDR usadas nas regras de LAN e origem opcional.
# Parâmetro: endereço de rede seguido de prefixo.
validar_cidr() {
    local valor="$1"
    local endereco="${valor%/*}"
    local prefixo="${valor##*/}"

    [[ "${valor}" == */* ]] || return 1
    validar_ipv4 "${endereco}" || return 1
    [[ "${prefixo}" =~ ^([1-9]|[12][0-9]|3[0-2])$ ]]
}

# Limpa todas as regras em tabelas usadas pelo projeto e restaura políticas seguras.
# Nenhum parâmetro; serve para recuperação emergencial.
limpar_firewall() {
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -t nat -P PREROUTING ACCEPT
    iptables -t nat -P INPUT ACCEPT
    iptables -t nat -P OUTPUT ACCEPT
    iptables -t nat -P POSTROUTING ACCEPT
    iptables -t mangle -P PREROUTING ACCEPT
    iptables -t mangle -P INPUT ACCEPT
    iptables -t mangle -P FORWARD ACCEPT
    iptables -t mangle -P OUTPUT ACCEPT
    iptables -t mangle -P POSTROUTING ACCEPT
    iptables -F
    iptables -X
    iptables -Z
    iptables -t nat -F
    iptables -t nat -X
    iptables -t nat -Z
    iptables -t mangle -F
    iptables -t mangle -X
    iptables -t mangle -Z
    printf 'Firewall liberado em memória: políticas ACCEPT e regras zeradas. O arquivo persistente foi preservado.\n'
}

# Zera as listas recent usadas por varredura e SSH sem alterar o restante das regras.
# Nenhum parâmetro.
liberar_scan() {
    local lista
    for lista in SCAN SSH; do
        if [[ -w "/proc/net/xt_recent/${lista}" ]]; then
            printf '/\n' > "/proc/net/xt_recent/${lista}"
        else
            printf 'ERRO: não foi possível zerar a lista recent %s.\n' "${lista}" >&2
            return 1
        fi
    done
    printf 'Listas recent SCAN e SSH zeradas.\n'
}

# Habilita encaminhamento persistente e limpa as tabelas antes da reconstrução.
# Nenhum parâmetro.
preparar_tabelas() {
    sysctl -w net.ipv4.ip_forward=1 >/dev/null
    install -d -m 755 /etc/sysctl.d
    printf 'net.ipv4.ip_forward = 1\n' > /etc/sysctl.d/99-saas-forward.conf

    iptables -F
    iptables -X
    iptables -Z
    iptables -t nat -F
    iptables -t nat -X
    iptables -t nat -Z
    iptables -t mangle -F
    iptables -t mangle -X
    iptables -t mangle -Z
}

# Define políticas padrões antes de inserir liberações explícitas.
# Nenhum parâmetro.
configurar_politicas() {
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
}

# Permite tráfego local e descarta estados que não podem ser processados de forma segura.
# Nenhum parâmetro.
configurar_estado_basico() {
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A FORWARD -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    iptables -A FORWARD -m conntrack --ctstate INVALID -j DROP
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
}

# Descarta combinações inválidas de flags e identifica tentativas de varredura.
# Nenhum parâmetro.
configurar_varredura() {
    iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP
    iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
    iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP

    # Esta regra registra NEW em portas não liberadas em um único conjunto recent.
    iptables -A INPUT -p tcp -m conntrack --ctstate NEW \
        -m multiport ! --dports "${PORTA_HTTP},${PORTA_HTTPS},${PORTA_SSH},${PORTA_DB}" \
        -m recent --name SCAN --set

    iptables -A INPUT -m recent --name SCAN --rcheck \
        --seconds "${SCAN_SEGUNDOS}" --hitcount "${SCAN_TENTATIVAS}" --rsource -j DROP
}

# Aplica limites por origem a SSH, HTTP, HTTPS e ICMP.
# Nenhum parâmetro.
configurar_taxas() {
    iptables -A INPUT -p tcp --dport "${PORTA_SSH}" -s "${LAN_REDE}" \
        -m conntrack --ctstate NEW -m recent --name SSH --update \
        --seconds "${SSH_SEGUNDOS}" \
        --hitcount "$((SSH_MAX_CONEXOES + 1))" --rsource -j DROP
    iptables -A INPUT -p tcp --dport "${PORTA_SSH}" -s "${LAN_REDE}" \
        -m conntrack --ctstate NEW -m recent --name SSH --set --rsource -j ACCEPT
    if [[ -n "${DEPLOY_ORIGEM}" ]]; then
        iptables -A INPUT -p tcp --dport "${PORTA_SSH}" -s "${DEPLOY_ORIGEM}" \
            -m conntrack --ctstate NEW -m recent --name SSH --update \
            --seconds "${SSH_SEGUNDOS}" \
            --hitcount "$((SSH_MAX_CONEXOES + 1))" --rsource -j DROP
        iptables -A INPUT -p tcp --dport "${PORTA_SSH}" -s "${DEPLOY_ORIGEM}" \
            -m conntrack --ctstate NEW -m recent --name SSH --set --rsource -j ACCEPT
    fi

    iptables -A INPUT -p tcp --dport "${PORTA_HTTP}" -m conntrack --ctstate NEW \
        -m hashlimit --hashlimit-name saas_http_per_ip --hashlimit-mode srcip \
        --hashlimit-above "${HTTP_LIMIT}" --hashlimit-burst "${HTTP_BURST}" -j DROP
    iptables -A INPUT -p tcp --dport "${PORTA_HTTPS}" -m conntrack --ctstate NEW \
        -m hashlimit --hashlimit-name saas_https_per_ip --hashlimit-mode srcip \
        --hashlimit-above "${HTTPS_LIMIT}" --hashlimit-burst "${HTTPS_BURST}" -j DROP

    iptables -A INPUT -p icmp --icmp-type echo-request \
        -m limit --limit "${ICMP_LIMIT}" --limit-burst "${ICMP_BURST}" -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
}

# Libera somente os serviços previstos na política da arquitetura.
# Nenhum parâmetro.
configurar_servicos() {
    iptables -A INPUT -p tcp --dport "${PORTA_HTTP}" -m conntrack --ctstate NEW -j ACCEPT
    iptables -A INPUT -p tcp --dport "${PORTA_HTTPS}" -m conntrack --ctstate NEW -j ACCEPT

    iptables -A INPUT -p tcp --dport "${PORTA_DB}" -s "${LAN_REDE}" \
        -m conntrack --ctstate NEW -j ACCEPT
}

# Libera saída da LAN para a WAN e bloqueia o caminho inverso com registro limitado.
# Nenhum parâmetro.
configurar_encaminhamento() {
    iptables -A FORWARD -s "${LAN_REDE}" -o "${IFACE_WAN}" \
        -m conntrack --ctstate NEW -j ACCEPT
    iptables -A FORWARD -i "${IFACE_WAN}" -d "${LAN_REDE}" \
        -m conntrack --ctstate NEW -m limit --limit "${LOG_LIMIT}" \
        --limit-burst "${LOG_BURST}" -j LOG --log-prefix "FW-FORWARD-DROP "
    iptables -A FORWARD -i "${IFACE_WAN}" -d "${LAN_REDE}" \
        -m conntrack --ctstate NEW -j DROP

    iptables -t nat -A POSTROUTING -s "${LAN_REDE}" -o "${IFACE_WAN}" -j MASQUERADE
}

# Registra pacotes INPUT descartados antes da política DROP final.
# Nenhum parâmetro.
configurar_log_e_persistencia() {
    iptables -A INPUT -m limit --limit "${LOG_LIMIT}" --limit-burst "${LOG_BURST}" \
        -j LOG --log-prefix "FW-INPUT-DROP "

    install -d -m 700 "$(dirname -- "${ARQUIVO_REGRAS_IPTABLES}")"
    iptables-save > "${ARQUIVO_REGRAS_IPTABLES}"
    chmod 600 "${ARQUIVO_REGRAS_IPTABLES}"
}

# Configura a unidade de inicialização que restaura as regras persistidas.
# Nenhum parâmetro.
instalar_unidade() {
    if [[ "${ARQUIVO_REGRAS_IPTABLES}" != "/etc/iptables/saas-firewall.rules" ]]; then
        printf 'ERRO: a unidade systemd está configurada para /etc/iptables/saas-firewall.rules.\n' >&2
        exit 1
    fi
    install -m 644 "${UNIT_SOURCE}" "${UNIT_DEST}"
    systemctl daemon-reload
    systemctl enable --now "${UNIT_NAME}"
}

# Monta integralmente as regras em memória e na unidade de inicialização.
# Nenhum parâmetro.
aplicar_firewall() {
    preparar_tabelas
    configurar_politicas
    configurar_estado_basico
    configurar_varredura
    configurar_taxas
    configurar_servicos
    configurar_encaminhamento
    configurar_log_e_persistencia
    instalar_unidade
    printf 'Firewall aplicado e persistido em %s.\n' "${ARQUIVO_REGRAS_IPTABLES}"
}

# Cria snapshot das tabelas para o modo de teste temporizado.
# Parâmetro: caminho do arquivo temporário.
backup_regras() {
    local destino="$1"
    iptables-save > "${destino}"
}

# Testa as novas regras e restaura o snapshot ao final do prazo sem --confirmar.
# Parâmetros: segundos de prazo e indicação de confirmação permanente.
testar_firewall() {
    local segundos="$1"
    local confirmar="$2"
    local backup
    local backup_arquivo=""
    local confirmacao="/run/saas-firewall.confirmar"
    local confirmada=false
    local elapsed

    validar_inteiro "${segundos}" || {
        printf 'ERRO: o prazo de --teste deve ser um inteiro positivo.\n' >&2
        return 1
    }
    backup="$(mktemp)"
    backup_regras "${backup}"
    rm -f -- "${confirmacao}"
    if [[ -f "${ARQUIVO_REGRAS_IPTABLES}" ]]; then
        backup_arquivo="$(mktemp)"
        cp -- "${ARQUIVO_REGRAS_IPTABLES}" "${backup_arquivo}"
        trap 'if [ ! -f "'"${confirmacao}"'" ]; then iptables-restore < "'"${backup}"'" 2>/dev/null || true; install -m 600 "'"${backup_arquivo}"'" "'"${ARQUIVO_REGRAS_IPTABLES}"'"; fi; rm -f -- "'"${backup}"'" "'"${backup_arquivo}"'" "'"${confirmacao}"'"' EXIT
    else
        trap 'if [ ! -e "'"${confirmacao}"'" ]; then iptables-restore < "'"${backup}"'" 2>/dev/null || true; rm -f -- "'"${ARQUIVO_REGRAS_IPTABLES}"'" ; fi; rm -f -- "'"${backup}"'" "'"${confirmacao}"'"' EXIT
    fi

    aplicar_firewall

    if [[ "${confirmar}" == true ]]; then
        trap - EXIT
        rm -f -- "${confirmacao}"
        rm -f -- "${backup}" "${backup_arquivo}"
        printf 'Regras confirmadas; o backup temporário não será restaurado.\n'
        return 0
    fi

    printf 'Regras em teste por %s segundos. Mantenha o console aberto.\n' "${segundos}"
    printf 'Em outra sessão, confirme com: sudo bash scripts/firewall.sh --confirmar\n'
    for (( elapsed=0; elapsed<segundos; elapsed++)); do
        if [[ -f "${confirmacao}" ]]; then
            confirmada=true
            break
        fi
        sleep 1
    done
    if [[ "${confirmada}" == true ]]; then
        trap - EXIT
        rm -f -- "${confirmacao}" "${backup}" "${backup_arquivo}"
        printf 'Regras confirmadas pelo operador; o backup temporário não será restaurado.\n'
        return 0
    fi
    iptables-restore < "${backup}"
    if [[ -n "${backup_arquivo}" ]]; then
        install -m 600 "${backup_arquivo}" "${ARQUIVO_REGRAS_IPTABLES}"
    else
        rm -f -- "${ARQUIVO_REGRAS_IPTABLES}"
    fi
    rm -f -- "${backup}" "${backup_arquivo}"
    trap - EXIT
    printf 'Prazo concluído; regras anteriores restauradas.\n'
}

# Valida dependências externas antes de executar qualquer alteração.
# Nenhum parâmetro.
validar_ambiente() {
    if (( EUID != 0)); then
        printf 'ERRO: execute este script como root.\n' >&2
        exit 1
    fi
    if [[ ! -r "${LAB_ENV}" ]]; then
        printf 'ERRO: não encontrei config/lab.env.\n' >&2
        exit 1
    fi
    source "${LAB_ENV}"

    local required_vars=(
        LAN_REDE PORTA_SSH PORTA_HTTP PORTA_HTTPS PORTA_DB IFACE_WAN IFACE_LAN
        ARQUIVO_REGRAS_IPTABLES SCAN_SEGUNDOS SCAN_TENTATIVAS SSH_SEGUNDOS
        SSH_MAX_CONEXOES HTTP_LIMIT HTTP_BURST HTTPS_LIMIT HTTPS_BURST
        ICMP_LIMIT ICMP_BURST LOG_LIMIT LOG_BURST
    )
    local variable_name
    for variable_name in "${required_vars[@]}"; do
        if [[ -z "${!variable_name:-}" || "${!variable_name}" == "DEFINIR" ]]; then
            printf 'ERRO: defina %s em config/lab.env antes de continuar.\n' "${variable_name}" >&2
            exit 1
        fi
    done

    validar_cidr "${LAN_REDE}" || {
        printf 'ERRO: LAN_REDE deve ser uma rede CIDR válida.\n' >&2
        exit 1
    }
    validar_origem "${DEPLOY_ORIGEM:-}" || {
        printf 'ERRO: DEPLOY_ORIGEM deve ser um IPv4 ou CIDR válido.\n' >&2
        exit 1
    }

    for variable_name in PORTA_SSH PORTA_HTTP PORTA_HTTPS PORTA_DB SCAN_SEGUNDOS SCAN_TENTATIVAS SSH_SEGUNDOS SSH_MAX_CONEXOES HTTP_BURST HTTPS_BURST ICMP_BURST LOG_BURST; do
        validar_inteiro "${!variable_name}" || {
            printf 'ERRO: %s deve ser um inteiro positivo.\n' "${variable_name}" >&2
            exit 1
        }
    done
    for variable_name in PORTA_SSH PORTA_HTTP PORTA_HTTPS PORTA_DB; do
        local port_value="${!variable_name}"
        if (( port_value < 1 || port_value > 65535)); then
            printf 'ERRO: %s deve estar entre 1 e 65535.\n' "${variable_name}" >&2
            exit 1
        fi
    done

    if [[ "${PORTA_SSH}" == "22" ]]; then
        printf 'ERRO: PORTA_SSH deve ser uma porta alta, não a porta 22.\n' >&2
        exit 1
    fi
    if [[ -z "${IFACE_WAN:-}" || -z "${IFACE_LAN:-}" || -z "${ARQUIVO_REGRAS_IPTABLES:-}" ]]; then
        printf 'ERRO: confira IFACE_WAN, IFACE_LAN e ARQUIVO_REGRAS_IPTABLES.\n' >&2
        exit 1
    fi
    if [[ "${IFACE_WAN}" == "${IFACE_LAN}" ]]; then
        printf 'ERRO: IFACE_WAN e IFACE_LAN devem ser interfaces diferentes.\n' >&2
        exit 1
    fi
    if [[ ! -d "/sys/class/net/${IFACE_WAN}" || ! -d "/sys/class/net/${IFACE_LAN}" ]]; then
        printf 'ERRO: as interfaces IFACE_WAN e IFACE_LAN devem existir no sistema.\n' >&2
        exit 1
    fi
    if [[ "${ARQUIVO_REGRAS_IPTABLES}" != /* ]]; then
        printf 'ERRO: ARQUIVO_REGRAS_IPTABLES deve ser um caminho absoluto.\n' >&2
        exit 1
    fi

    command -v iptables >/dev/null 2>&1 || {
        printf 'ERRO: iptables não está instalado.\n' >&2
        exit 1
    }
    command -v iptables-save >/dev/null 2>&1 || {
        printf 'ERRO: iptables-save não está instalado.\n' >&2
        exit 1
    }
    command -v iptables-restore >/dev/null 2>&1 || {
        printf 'ERRO: iptables-restore não está instalado.\n' >&2
        exit 1
    }
    command -v sysctl >/dev/null 2>&1 || {
        printf 'ERRO: sysctl não está instalado.\n' >&2
        exit 1
    }
}

mostrar_status() {
    printf 'Políticas e regras efetivas:\n'
    iptables -S
    iptables -t nat -S
    iptables -t mangle -S
    if [[ -f "${ARQUIVO_REGRAS_IPTABLES}" ]]; then
        printf '\nArquivo persistente: %s\n' "${ARQUIVO_REGRAS_IPTABLES}"
        stat -c '%a %U:%G %n' "${ARQUIVO_REGRAS_IPTABLES}"
    else
        printf '\nArquivo persistente ainda não existe: %s\n' "${ARQUIVO_REGRAS_IPTABLES}"
    fi
}

modo="--aplicar"
teste_segundos=""
confirmar=false
readonly CONFIRMACAO="/run/saas-firewall.confirmar"

if (( $# > 0)); then
    modo="$1"
    shift
fi

case "${modo}" in
    --aplicar|--status|--limpar|--liberar-scan|--teste)
        ;;
    --confirmar)
        if (( EUID != 0)); then
            printf 'ERRO: execute --confirmar como root.\n' >&2
            exit 1
        fi
        if [[ -d "/run" ]]; then
            : > "${CONFIRMACAO}"
            printf 'Confirmação registrada para o modo --teste em execução.\n'
            exit 0
        fi
        printf 'ERRO: /run não está disponível para registrar a confirmação.\n' >&2
        exit 1
        ;;
    *)
        printf 'Uso: sudo bash scripts/firewall.sh [--aplicar|--status|--limpar|--liberar-scan|--teste SEGUNDOS [--confirmar]]\n' >&2
        exit 1
        ;;
esac

validar_ambiente

case "${modo}" in
    --aplicar)
        if (( $# != 0)); then
            printf 'ERRO: --aplicar não aceita parâmetros adicionais.\n' >&2
            exit 1
        fi
        aplicar_firewall
        ;;
    --status)
        if (( $# != 0)); then
            printf 'ERRO: --status não aceita parâmetros adicionais.\n' >&2
            exit 1
        fi
        mostrar_status
        ;;
    --limpar)
        if (( $# != 0)); then
            printf 'ERRO: --limpar não aceita parâmetros adicionais.\n' >&2
            exit 1
        fi
        limpar_firewall
        ;;
    --liberar-scan)
        if (( $# != 0)); then
            printf 'ERRO: --liberar-scan não aceita parâmetros adicionais.\n' >&2
            exit 1
        fi
        liberar_scan
        ;;
    --teste)
        if (( $# < 1)); then
            printf 'ERRO: use --teste SEGUNDOS [--confirmar].\n' >&2
            exit 1
        fi
        teste_segundos="$1"
        shift
        if (( $# > 0)); then
            if [[ "$1" == "--confirmar" && $# == 1 ]]; then
                confirmar=true
            else
                printf 'ERRO: após os segundos use somente --confirmar.\n' >&2
                exit 1
            fi
        fi
        testar_firewall "${teste_segundos}" "${confirmar}"
        ;;
esac
