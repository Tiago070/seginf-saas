#!/usr/bin/env bash
# Nome: testes-servidor.sh
# Finalidade: Verificar localmente SSH, firewall, sistema operacional e integridade.
# Autor: DEFINIR
# Data: 19/11/2026
# Requisitos: Bash, Ubuntu Server e utilitários do laboratório.
# Uso: sudo bash tests/testes-servidor.sh
# Requisito do trabalho atendido: R2.5, R2.6 e R3.2
# Fonte externa: nenhuma

set -euo pipefail
IFS=$'\n\t'

readonly REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly LAB_ENV="${REPO_DIR}/config/lab.env"
falhas=0

# Executa uma verificação isolada para continuar e apresentar todos os resultados.
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

if (( EUID != 0 )); then
    printf 'ERRO: execute como root.\n' >&2
    exit 1
fi
source "${LAB_ENV}"

if ! configuracao_sshd="$(sshd -T)"; then
    printf 'FAIL S01 sshd -T não conseguiu carregar a configuração efetiva.\n' >&2
    exit 1
fi
sockets="$(ss -H -tlnp)"

verificar S01 "sshd -t" sshd -t
grep -Fxq "port ${PORTA_SSH}" <<< "${configuracao_sshd}" \
    && printf 'PASS S02 porta SSH efetiva %s\n' "${PORTA_SSH}" \
    || { printf 'FAIL S02 porta SSH efetiva %s\n' "${PORTA_SSH}"; falhas=$((falhas + 1)); }
grep -Fxq 'permitrootlogin no' <<< "${configuracao_sshd}" \
    && printf 'PASS S03 root SSH bloqueado\n' \
    || { printf 'FAIL S03 root SSH bloqueado\n'; falhas=$((falhas + 1)); }
grep -Fxq 'passwordauthentication no' <<< "${configuracao_sshd}" \
    && printf 'PASS S04 autenticação SSH por senha desativada\n' \
    || { printf 'FAIL S04 autenticação SSH por senha desativada\n'; falhas=$((falhas + 1)); }
grep -Fxq 'kbdinteractiveauthentication no' <<< "${configuracao_sshd}" \
    && printf 'PASS S05 autenticação interativa desativada\n' \
    || { printf 'FAIL S05 autenticação interativa desativada\n'; falhas=$((falhas + 1)); }
grep -Fxq 'pubkeyauthentication yes' <<< "${configuracao_sshd}" \
    && printf 'PASS S06 autenticação por chave habilitada\n' \
    || { printf 'FAIL S06 autenticação por chave habilitada\n'; falhas=$((falhas + 1)); }
grep -Fxq 'authenticationmethods publickey' <<< "${configuracao_sshd}" \
    && printf 'PASS S07 autenticação exclusivamente por chave\n' \
    || { printf 'FAIL S07 autenticação exclusivamente por chave\n'; falhas=$((falhas + 1)); }
allowusers_efetivo="$(sed -n 's/^allowusers //p' <<< "${configuracao_sshd}")"
IFS=',' read -r -a usuarios_admin <<< "${USUARIOS_ADMIN}"
for usuario_admin in "${usuarios_admin[@]}"; do
    usuario_admin="${usuario_admin//[[:space:]]/}"
    if [[ " ${allowusers_efetivo} " == *" ${usuario_admin}@${LAN_REDE} "* ]]; then
        printf 'PASS S08 AllowUsers contém %s na LAN\n' "${usuario_admin}"
    else
        printf 'FAIL S08 AllowUsers não contém %s na LAN\n' "${usuario_admin}"
        falhas=$((falhas + 1))
    fi
done
if [[ " ${allowusers_efetivo} " == *" ${USUARIO_DEPLOY}@${LAN_REDE} "* ]]; then
    printf 'PASS S09 AllowUsers contém deploy na LAN\n'
else
    printf 'FAIL S09 AllowUsers não contém deploy na LAN\n'
    falhas=$((falhas + 1))
fi
grep -Eq "[.:]${PORTA_SSH}[[:space:]]" <<< "${sockets}" \
    && printf 'PASS S10 listener SSH na porta %s\n' "${PORTA_SSH}" \
    || { printf 'FAIL S10 listener SSH na porta %s\n' "${PORTA_SSH}"; falhas=$((falhas + 1)); }
if grep -Eq '(^|[.:])22[[:space:]]' <<< "${sockets}"; then
    printf 'FAIL S11 listener na porta 22\n'
    falhas=$((falhas + 1))
else
    printf 'PASS S11 sem listener na porta 22\n'
fi
politica_drop() {
    local cadeia="$1"
    iptables -S "${cadeia}" | grep -Fxq -- "-P ${cadeia} DROP"
}
sem_atualizacoes() {
    local simulacao
    simulacao="$(LC_ALL=C apt-get -s upgrade)" || return 1
    ! grep -q '^Inst ' <<< "${simulacao}"
}
nenhuma_unidade_falhou() {
    local unidades
    unidades="$(systemctl list-units --state=failed --no-legend --plain --no-pager)" || return 1
    [[ -z "${unidades}" ]]
}
verificar S12 "política INPUT DROP" politica_drop INPUT
verificar S13 "política FORWARD DROP" politica_drop FORWARD
verificar S14 "verificação da linha de base" \
    bash "${REPO_DIR}/scripts/verifica-integridade.sh" --check
permissao_exata() {
    local caminho="$1"
    local esperado="$2"
    [[ "$(stat -c '%a:%U:%G' "${caminho}")" == "${esperado}" ]]
}
verificar S15 "modo seguro de /etc/passwd" \
    permissao_exata /etc/passwd 644:root:root
verificar S16 "modo restrito de /etc/shadow" \
    permissao_exata /etc/shadow 640:root:shadow
verificar S17 "modo restrito de /etc/sudoers" \
    permissao_exata /etc/sudoers 440:root:root
verificar S18 "nenhuma unidade systemd falhou" \
    nenhuma_unidade_falhou
verificar S19 "SSH ativo" systemctl is-active --quiet ssh.service
verificar S20 "Nginx ativo" systemctl is-active --quiet nginx.service
verificar S21 "PostgreSQL ativo" systemctl is-active --quiet postgresql.service
verificar S22 "firewall persistente ativo" systemctl is-active --quiet saas-firewall.service
verificar S23 "nenhuma atualização pendente" sem_atualizacoes

if (( falhas > 0 )); then
    printf 'Resultado: %s falha(s).\n' "${falhas}" >&2
    exit 1
fi
printf 'Resultado: todas as verificações locais passaram.\n'
