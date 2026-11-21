#!/usr/bin/env bash
# Nome: verifica-integridade.sh
# Finalidade: Criar e verificar uma linha de base SHA-256 dos arquivos críticos.
# Data: 19/11/2026
# Requisitos: Bash, coreutils, logger, config/lab.env e acesso root.
# Uso: sudo bash scripts/verifica-integridade.sh [--init|--check|--atualizar MOTIVO|--instalar-agendamento]
# Requisito do trabalho atendido: R3.2
# Fonte externa: nenhuma

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly LAB_ENV="${REPO_DIR}/config/lab.env"

DIR_BASELINE_INTEGRIDADE=""
ARQUIVO_REGRAS_IPTABLES=""
ARQUIVO_PASSWD=""
ARQUIVO_SHADOW=""
INTEGRIDADE_INTERVALO_MINUTOS=""
ARQUIVO_LOG_INTEGRIDADE=""
ARQUIVO_CRON_INTEGRIDADE=""
BASELINE_DIR=""
BASELINE_FILE=""
temporary_file=""

# Remove arquivo temporário mesmo quando a comparação encontra divergência.
# Nenhum parâmetro.
limpar_temporario() {
    if [[ -n "${temporary_file}" ]]; then
        rm -f -- "${temporary_file}"
    fi
}
trap limpar_temporario EXIT

# Registra o evento no log local e no journal para permitir revisão por mais de uma via.
# Parâmetros: prioridade syslog e mensagem sem dados secretos.
registrar_evento() {
    local prioridade="$1"
    local mensagem="$2"
    local linha
    linha="$(date --iso-8601=seconds) ${mensagem}"
    if [[ -L "${ARQUIVO_LOG_INTEGRIDADE}" ]]; then
        printf 'ERRO: o caminho do log não pode ser link simbólico.\n' >&2
        return 1
    fi
    if [[ ! -e "${ARQUIVO_LOG_INTEGRIDADE}" ]]; then
        install -d -o root -g root -m 755 "$(dirname -- "${ARQUIVO_LOG_INTEGRIDADE}")"
        install -o root -g root -m 600 /dev/null "${ARQUIVO_LOG_INTEGRIDADE}"
    fi
    chown root:root "${ARQUIVO_LOG_INTEGRIDADE}"
    chmod 600 "${ARQUIVO_LOG_INTEGRIDADE}"
    printf '%s\n' "${linha}" >> "${ARQUIVO_LOG_INTEGRIDADE}"
    logger -p "auth.${prioridade}" -t saas-integridade -- "${mensagem}"
}

# Confere que a linha de base não pode ser alterada por usuários comuns.
# Nenhum parâmetro.
validar_permissoes_baseline() {
    local modo_diretorio
    local modo_arquivo
    [[ -d "${BASELINE_DIR}" && -f "${BASELINE_FILE}" ]] || {
        printf 'ERRO: linha de base ausente. Execute --init primeiro.\n' >&2
        return 1
    }
    modo_diretorio="$(stat -c '%u:%a' "${BASELINE_DIR}")"
    modo_arquivo="$(stat -c '%u:%a' "${BASELINE_FILE}")"
    if [[ "${modo_diretorio}" != "0:700" || "${modo_arquivo}" != "0:600" ]]; then
        printf 'ERRO: a linha de base deve pertencer a root e usar modos 700/600.\n' >&2
        return 1
    fi
}

# Cria uma versão temporária da linha de base e instala-a atomicamente.
# Nenhum parâmetro.
criar_baseline() {
    local arquivo
    local temporario
    local -a arquivos=(
        "${ARQUIVO_PASSWD}"
        "${ARQUIVO_SHADOW}"
        "${ARQUIVO_REGRAS_IPTABLES}"
    )
    for arquivo in "${arquivos[@]}"; do
        if [[ ! -f "${arquivo}" || ! -r "${arquivo}" ]]; then
            printf 'ERRO: arquivo monitorado ausente ou ilegível: %s\n' "${arquivo}" >&2
            return 1
        fi
    done
    install -d -o root -g root -m 700 "${BASELINE_DIR}"
    temporario="$(mktemp "${BASELINE_DIR}/baseline.XXXXXX")"
    temporary_file="${temporario}"
    sha256sum -- "${arquivos[@]}" > "${temporario}"
    install -o root -g root -m 600 "${temporario}" "${BASELINE_FILE}"
    rm -f -- "${temporario}"
    temporary_file=""
    printf 'Linha de base gravada em %s\n' "${BASELINE_FILE}"
}

# Compara os hashes atuais com a linha de base e retorna 2 em caso de alteração.
# Nenhum parâmetro.
verificar_baseline() {
    local diferencas
    local -a arquivos=(
        "${ARQUIVO_PASSWD}"
        "${ARQUIVO_SHADOW}"
        "${ARQUIVO_REGRAS_IPTABLES}"
    )
    validar_permissoes_baseline
    temporary_file="$(mktemp)"
    if ! sha256sum -- "${arquivos[@]}" > "${temporary_file}"; then
        registrar_evento alert "ERRO ao calcular hashes dos arquivos monitorados."
        return 2
    fi
    if cmp -s -- "${BASELINE_FILE}" "${temporary_file}"; then
        registrar_evento notice "OK: arquivos monitorados sem divergência."
        printf 'OK: arquivos monitorados sem divergência.\n'
        return 0
    fi

    diferencas="$(diff -u -- "${BASELINE_FILE}" "${temporary_file}" || true)"
    printf 'ALERTA: divergência na linha de base SHA-256.\n%s\n' "${diferencas}" >&2
    registrar_evento alert "ALERTA: divergência na linha de base SHA-256."
    return 2
}

# Instala uma tarefa cron usando caminho absoluto para execução periódica.
# Nenhum parâmetro.
instalar_agendamento() {
    local conteudo
    if [[ ! "${INTEGRIDADE_INTERVALO_MINUTOS}" =~ ^[1-9][0-9]?$ ]] \
        || (( INTEGRIDADE_INTERVALO_MINUTOS > 59 )); then
        printf 'ERRO: INTEGRIDADE_INTERVALO_MINUTOS deve estar entre 1 e 59.\n' >&2
        return 1
    fi
    validar_permissoes_baseline
    if [[ -L "${ARQUIVO_CRON_INTEGRIDADE}" ]]; then
        printf 'ERRO: o caminho do cron não pode ser link simbólico.\n' >&2
        return 1
    fi
    conteudo="*/${INTEGRIDADE_INTERVALO_MINUTOS} * * * * root /usr/bin/env bash \"${SCRIPT_DIR}/verifica-integridade.sh\" --check >/dev/null 2>&1"
    printf '%s\n' "${conteudo}" > "${ARQUIVO_CRON_INTEGRIDADE}"
    chown root:root "${ARQUIVO_CRON_INTEGRIDADE}"
    chmod 644 "${ARQUIVO_CRON_INTEGRIDADE}"
    systemctl restart cron.service
    printf 'Agendamento instalado em %s\n' "${ARQUIVO_CRON_INTEGRIDADE}"
}

if (( EUID != 0 )); then
    printf 'ERRO: execute como root, por exemplo: sudo bash scripts/verifica-integridade.sh --check\n' >&2
    exit 1
fi
if [[ ! -r "${LAB_ENV}" ]]; then
    printf 'ERRO: não encontrei config/lab.env.\n' >&2
    exit 1
fi
source "${LAB_ENV}"

for variable_name in DIR_BASELINE_INTEGRIDADE ARQUIVO_REGRAS_IPTABLES \
    ARQUIVO_PASSWD ARQUIVO_SHADOW \
    INTEGRIDADE_INTERVALO_MINUTOS ARQUIVO_LOG_INTEGRIDADE ARQUIVO_CRON_INTEGRIDADE; do
    if [[ -z "${!variable_name:-}" || "${!variable_name}" == "DEFINIR" ]]; then
        printf 'ERRO: defina %s em config/lab.env.\n' "${variable_name}" >&2
        exit 1
    fi
done
if [[ "${DIR_BASELINE_INTEGRIDADE}" != /* || "${DIR_BASELINE_INTEGRIDADE}" == "/" \
    || "${ARQUIVO_LOG_INTEGRIDADE}" != /* || "${ARQUIVO_CRON_INTEGRIDADE}" != /* \
    || "${ARQUIVO_REGRAS_IPTABLES}" != /* || "${ARQUIVO_PASSWD}" != /* \
    || "${ARQUIVO_SHADOW}" != /* ]]; then
    printf 'ERRO: diretórios e arquivos de integridade devem usar caminhos absolutos.\n' >&2
    exit 1
fi
BASELINE_DIR="${DIR_BASELINE_INTEGRIDADE}"
BASELINE_FILE="${BASELINE_DIR}/baseline.sha256"

if (( $# == 0 )); then
    set -- --check
fi
case "$1" in
    --init)
        if (( $# != 1 )) || [[ -e "${BASELINE_FILE}" || -L "${BASELINE_FILE}" ]]; then
            printf 'ERRO: --init não aceita argumentos nem sobrescreve uma linha de base existente.\n' >&2
            exit 1
        fi
        criar_baseline
        registrar_evento notice "Linha de base inicial criada por $(id -un)."
        ;;
    --check)
        if (( $# != 1 )); then
            printf 'Uso: sudo bash scripts/verifica-integridade.sh --check\n' >&2
            exit 1
        fi
        verificar_baseline
        ;;
    --atualizar)
        if (( $# != 2 )) || [[ -z "$2" ]]; then
            printf 'Uso: sudo bash scripts/verifica-integridade.sh --atualizar \"MOTIVO\"\n' >&2
            exit 1
        fi
        criar_baseline
        registrar_evento notice "Linha de base atualizada por $(id -un). Motivo: $2"
        ;;
    --instalar-agendamento)
        if (( $# != 1 )); then
            printf 'Uso: sudo bash scripts/verifica-integridade.sh --instalar-agendamento\n' >&2
            exit 1
        fi
        instalar_agendamento
        ;;
    *)
        printf 'Uso: sudo bash scripts/verifica-integridade.sh [--init|--check|--atualizar MOTIVO|--instalar-agendamento]\n' >&2
        exit 1
        ;;
esac
