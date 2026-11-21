#!/usr/bin/env bash
# Nome: hardening-so.sh
# Finalidade: Relatar e aplicar ajustes pontuais de hardening do Ubuntu Server.
# Data: 19/11/2026
# Requisitos: Bash, Ubuntu Server, apt-get e acesso root.
# Uso: sudo bash scripts/hardening-so.sh [--relatorio|--aplicar]
# Requisito do trabalho atendido: R2.6
# Fonte externa: nenhuma

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly LAB_ENV="${REPO_DIR}/config/lab.env"
DIR_RELATORIO_HARDENING=""
SO_PACOTES_REMOVER=""
SO_SERVICOS_DESATIVAR=""
pacotes_remover=()
servicos_desativar=()

# Captura o estado antes e depois para permitir comparação e auditoria.
# Parâmetro: rótulo "antes" ou "depois"; retorna o caminho do relatório.
gerar_relatorio() {
    local rotulo="$1"
    local marca_data
    local arquivo
    marca_data="$(date '+%Y%m%d-%H%M%S')"
    arquivo="${DIR_RELATORIO_HARDENING}/${rotulo}-${marca_data}.txt"
    install -d -m 700 -o root -g root "${DIR_RELATORIO_HARDENING}"

    {
        printf 'Data: %s\nHost: %s\nUsuário: %s\n' \
            "$(date --iso-8601=seconds)" "$(hostname)" "$(id -un)"
        printf '\n== Endereços e portas ==\n'
        ip -br addr
        ss -tlnp
        printf '\n== Serviços habilitados ==\n'
        systemctl list-unit-files --state=enabled --no-pager
        printf '\n== Pacotes instalados ==\n'
        dpkg-query -W -f='${binary:Package}\t${Version}\t${db:Status-Status}\n' \
            | awk -F '\t' '$3 == "installed" { print $1 "\t" $2 }'
        printf '\n== Permissões dos arquivos críticos ==\n'
        stat -c '%a %U:%G %n' /etc /var/log 2>&1 || true
        stat -c '%a %U:%G %n' \
            /etc/passwd /etc/group /etc/shadow /etc/gshadow \
            /etc/sudoers /etc/ssh/sshd_config /etc/crontab \
            /var/log/auth.log 2>&1 || true
        printf '\n== Atualizações disponíveis ==\n'
        apt list --upgradable 2>&1 || true
        printf '\n== Componentes de hardening avaliados ==\n'
        if ldd /usr/sbin/sshd 2>/dev/null | grep -q libwrap; then
            printf 'TCP Wrappers: aplicável, libwrap aparece nas dependências do sshd.\n'
        else
            printf 'TCP Wrappers: avaliado e não aplicável ao sshd instalado.\n'
        fi
        if [[ -e /etc/securetty ]]; then
            printf '/etc/securetty: presente.\n'
            stat -c '%a %U:%G %n' /etc/securetty
        else
            printf '/etc/securetty: avaliado e não aplicável, arquivo ausente.\n'
        fi
        systemctl is-enabled ctrl-alt-del.target 2>&1 || true
        passwd -S root 2>&1 || true
    } > "${arquivo}"
    chmod 600 "${arquivo}"
    printf 'Relatório salvo em %s\n' "${arquivo}"
}

# Converte listas CSV de lab.env em itens e valida nomes de pacote e serviço.
# Parâmetro: lista separada por vírgulas e tipo "pacote" ou "serviço".
validar_lista() {
    local lista="$1"
    local tipo="$2"
    local item
    local -a itens=()
    local antigo_ifs="${IFS}"
    IFS=','
    read -r -a itens <<< "${lista}"
    IFS="${antigo_ifs}"

    for item in "${itens[@]}"; do
        item="${item//[[:space:]]/}"
        [[ -z "${item}" ]] && continue
        if [[ "${tipo}" == "pacote" ]]; then
            [[ "${item}" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || {
                printf 'ERRO: nome de pacote inválido: %s\n' "${item}" >&2
                return 1
            }
            case "${item}" in
                openssh-server*|systemd|systemd-*|rsyslog*|cron*|nginx*|postgresql*|iptables*|netfilter-persistent*)
                    printf 'ERRO: o pacote essencial não pode ser removido: %s\n' "${item}" >&2
                    return 1
                    ;;
            esac
            pacotes_remover+=("${item}")
        else
            [[ "${item}" =~ ^[A-Za-z0-9_.@:-]+$ ]] || {
                printf 'ERRO: nome de serviço inválido: %s\n' "${item}" >&2
                return 1
            }
            case "${item}" in
                ssh|ssh.service|ssh.socket|systemd-*|rsyslog|rsyslog.service|cron|cron.service|nginx|nginx.service|postgresql|postgresql.service|saas-firewall|saas-firewall.service)
                    printf 'ERRO: o serviço protegido não pode ser desativado: %s\n' "${item}" >&2
                    return 1
                    ;;
            esac
            servicos_desativar+=("${item}")
        fi
    done
}

# Corrige permissões conhecidas de arquivos críticos sem alterar diretórios recursivamente.
# Nenhum parâmetro.
ajustar_permissoes() {
    local arquivo
    local modo
    local proprietario
    local grupo
    local ajuste
    local -a ajustes=(
        "/etc/passwd|644|root|root"
        "/etc/group|644|root|root"
        "/etc/shadow|640|root|shadow"
        "/etc/gshadow|640|root|shadow"
        "/etc/sudoers|440|root|root"
        "/etc/ssh/sshd_config|600|root|root"
        "/etc/crontab|644|root|root"
    )

    for ajuste in "${ajustes[@]}"; do
        IFS='|' read -r arquivo modo proprietario grupo <<< "${ajuste}"
        if [[ -f "${arquivo}" ]]; then
            chown "${proprietario}:${grupo}" "${arquivo}"
            chmod "${modo}" "${arquivo}"
        fi
    done
    if [[ -f /var/log/auth.log ]] && getent passwd syslog >/dev/null && getent group adm >/dev/null; then
        chown syslog:adm /var/log/auth.log
        chmod 640 /var/log/auth.log
    fi
}

# Remove apenas pacotes presentes e previamente aprovados em lab.env.
# Nenhum parâmetro.
remover_pacotes_aprovados() {
    local pacote
    for pacote in "${pacotes_remover[@]}"; do
        if [[ "$(dpkg-query -W -f='${db:Status-Status}' "${pacote}" 2>/dev/null || true)" == "installed" ]]; then
            apt-get purge -y -- "${pacote}"
        else
            printf 'Pacote %s ausente; nenhuma alteração.\n' "${pacote}"
        fi
    done
}

# Desativa somente serviços revisados e aprovados em lab.env.
# Nenhum parâmetro.
desativar_servicos_aprovados() {
    local servico
    local unidade
    for servico in "${servicos_desativar[@]}"; do
        unidade="${servico}"
        [[ "${unidade}" == *.* ]] || unidade="${unidade}.service"
        if systemctl cat "${unidade}" >/dev/null 2>&1; then
            systemctl disable --now "${unidade}"
        else
            printf 'Serviço %s ausente; nenhuma alteração.\n' "${unidade}"
        fi
    done
}

if (( EUID != 0 )); then
    printf 'ERRO: execute como root, por exemplo: sudo bash scripts/hardening-so.sh --relatorio\n' >&2
    exit 1
fi
if [[ ! -r "${LAB_ENV}" ]]; then
    printf 'ERRO: não encontrei config/lab.env.\n' >&2
    exit 1
fi
if (( $# != 1 )) || [[ "$1" != "--relatorio" && "$1" != "--aplicar" ]]; then
    printf 'Uso: sudo bash scripts/hardening-so.sh [--relatorio|--aplicar]\n' >&2
    exit 1
fi
source "${LAB_ENV}"
if [[ -z "${DIR_RELATORIO_HARDENING:-}" || "${DIR_RELATORIO_HARDENING}" != /* \
    || "${DIR_RELATORIO_HARDENING}" == "/" ]]; then
    printf 'ERRO: defina DIR_RELATORIO_HARDENING como caminho absoluto em config/lab.env.\n' >&2
    exit 1
fi
validar_lista "${SO_PACOTES_REMOVER:-}" pacote
validar_lista "${SO_SERVICOS_DESATIVAR:-}" serviço

if [[ "$1" == "--relatorio" ]]; then
    gerar_relatorio antes
    exit 0
fi

gerar_relatorio antes
if ((${#pacotes_remover[@]} > 0 || ${#servicos_desativar[@]} > 0)); then
    printf 'Pacotes aprovados: %s\nServiços aprovados: %s\n' \
        "${pacotes_remover[*]:-(nenhum)}" "${servicos_desativar[*]:-(nenhum)}"
    read -r -p 'Confirme que revisou os itens em lab.env e deseja aplicá-los [s/N]: ' resposta
    if [[ "${resposta}" != "s" && "${resposta}" != "S" ]]; then
        printf 'Operação cancelada antes de alterar pacotes ou serviços.\n' >&2
        exit 1
    fi
fi
ajustar_permissoes
remover_pacotes_aprovados
desativar_servicos_aprovados
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
gerar_relatorio depois
if ! simulacao_atualizacoes="$(LC_ALL=C apt-get -s upgrade)"; then
    printf 'ERRO: não foi possível verificar atualizações pendentes.\n' >&2
    exit 1
fi
if grep -qE '^Inst |^The following packages have been kept back:' <<< "${simulacao_atualizacoes}"; then
    printf 'ERRO: ainda há atualizações disponíveis; confira o relatório depois.\n' >&2
    exit 1
fi
printf 'Hardening aplicado. Reinicie a VM e valide os serviços antes de encerrar a etapa.\n'
