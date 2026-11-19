#!/usr/bin/env bash
# Nome: testes-lan.sh
# Finalidade: Verificar SSH nominal e acesso ao PostgreSQL pela LAN.
# Autor: DEFINIR
# Data: 19/11/2026
# Requisitos: Bash, OpenSSH client, netcat e config/lab.env.
# Uso: bash tests/testes-lan.sh
# Requisito do trabalho atendido: R2.3 e R2.5
# Fonte externa: nenhuma

set -euo pipefail
IFS=$'\n\t'

readonly REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly LAB_ENV="${REPO_DIR}/config/lab.env"
falhas=0

# Registra o resultado sem interromper os demais testes negativos.
# Parâmetros: identificador, descrição e comando com argumentos.
esperar_sucesso() {
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

# Confirma que um acesso proibido não resulta em sessão.
# Parâmetros: identificador, descrição e comando com argumentos.
esperar_bloqueio() {
    local id="$1"
    local descricao="$2"
    shift 2
    if "$@"; then
        printf 'FAIL %s %s\n' "${id}" "${descricao}"
        falhas=$((falhas + 1))
    else
        printf 'PASS %s %s\n' "${id}" "${descricao}"
    fi
}

source "${LAB_ENV}"
if ! command -v nc >/dev/null 2>&1; then
    printf 'ERRO: instale netcat-openbsd na estação para testar portas.\n' >&2
    exit 1
fi
IFS=',' read -r -a usuarios <<< "${USUARIOS_ADMIN}"
usuario="${usuarios[0]//[[:space:]]/}"
chave="${HOME}/.ssh/saas_${usuario}"
if [[ ! -r "${chave}" ]]; then
    printf 'ERRO: a chave privada de teste não foi encontrada em %s.\n' "${chave}" >&2
    exit 1
fi

ssh_opcoes=(
    -o ConnectTimeout=5
    -o IdentitiesOnly=yes
    -o PreferredAuthentications=publickey
    -i "${chave}"
    -p "${PORTA_SSH}"
)
esperar_sucesso L01 "login nominal por chave na porta configurada" \
    ssh "${ssh_opcoes[@]}" "${usuario}@${LAN_IP_SERVIDOR}" true
esperar_bloqueio L02 "login SSH direto como root recusado" \
    ssh "${ssh_opcoes[@]}" root@"${LAN_IP_SERVIDOR}" true
esperar_bloqueio L03 "autenticação SSH por senha recusada" \
    ssh -o BatchMode=yes -o ConnectTimeout=5 \
        -o PreferredAuthentications=password -o PubkeyAuthentication=no \
        -p "${PORTA_SSH}" "${usuario}@${LAN_IP_SERVIDOR}" true
esperar_sucesso L04 "PostgreSQL acessível pela LAN" \
    nc -z -w 3 "${LAN_IP_SERVIDOR}" "${PORTA_DB}"
esperar_bloqueio L05 "porta padrão 22 fechada na LAN" \
    nc -z -w 3 "${LAN_IP_SERVIDOR}" 22

if (( falhas > 0 )); then
    printf 'Resultado: %s falha(s).\n' "${falhas}" >&2
    exit 1
fi
printf 'Resultado: todas as verificações da LAN passaram.\n'
