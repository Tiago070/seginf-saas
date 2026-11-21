#!/usr/bin/env bash
# Nome: testes-externos.sh
# Finalidade: Verificar serviços públicos e portas que devem permanecer fechadas.
# Data: 19/11/2026
# Requisitos: Bash, curl, netcat e config/lab.env.
# Uso: bash tests/testes-externos.sh
# Requisito do trabalho atendido: R2.2, R2.3 e E4
# Fonte externa: nenhuma

set -euo pipefail
IFS=$'\n\t'

readonly REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly LAB_ENV="${REPO_DIR}/config/lab.env"
falhas=0

# Registra o resultado de uma verificação de rede limitada aos serviços do laboratório.
# Parâmetros: identificador, descrição e comando com argumentos.
verificar() {
    local id="$1"
    local descricao="$2"
    shift 2
    if "$@"; then
        printf 'PASS %s %s\n' "${id}" "${descricao}"
    else
        printf 'FAIL %s %s\n' "${id}" "${descricao}"
        falhas=$((falhas + 1))
    fi
}

# Confirma que um serviço HTTP responde com o código esperado.
# Parâmetros: endereço, porta e código HTTP esperado.
http_status() {
    local endereco="$1"
    local porta="$2"
    local esperado="$3"
    local recebido
    recebido="$(curl -k -sS -o /dev/null -w '%{http_code}' \
        --connect-timeout 4 --max-time 8 "http://${endereco}:${porta}/")"
    [[ "${recebido}" == "${esperado}" ]]
}

# Confirma que HTTPS responde sem depender da validação de certificado local.
# Parâmetros: endereço e porta.
https_responde() {
    local endereco="$1"
    local porta="$2"
    local recebido
    recebido="$(curl -k -sS -o /dev/null -w '%{http_code}' \
        --connect-timeout 4 --max-time 8 "https://${endereco}:${porta}/")"
    [[ "${recebido}" =~ ^2[0-9][0-9]$ ]]
}

source "${LAB_ENV}"
if ! command -v nc >/dev/null 2>&1; then
    printf 'ERRO: instale netcat-openbsd no cliente externo.\n' >&2
    exit 1
fi

verificar E01 "HTTP redireciona para HTTPS" http_status \
    "${WAN_IP_SERVIDOR}" "${PORTA_HTTP}" 301
verificar E02 "HTTPS responde" https_responde \
    "${WAN_IP_SERVIDOR}" "${PORTA_HTTPS}"
if nc -z -w 3 "${WAN_IP_SERVIDOR}" 22; then
    printf 'FAIL E03 porta 22 acessível pela WAN\n'
    falhas=$((falhas + 1))
else
    printf 'PASS E03 porta 22 fechada pela WAN\n'
fi
if nc -z -w 3 "${WAN_IP_SERVIDOR}" "${PORTA_DB}"; then
    printf 'FAIL E04 PostgreSQL acessível pela WAN\n'
    falhas=$((falhas + 1))
else
    printf 'PASS E04 PostgreSQL fechado pela WAN\n'
fi

if (( falhas > 0 )); then
    printf 'Resultado: %s falha(s).\n' "${falhas}" >&2
    exit 1
fi
printf 'Resultado: todas as verificações externas passaram.\n'
