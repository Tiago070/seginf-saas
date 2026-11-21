#!/usr/bin/env bash
# Nome: hardening-ssh.sh
# Finalidade: Instalar contas, chaves públicas e configuração segura do OpenSSH.
# Data: 19/11/2026
# Requisitos: Bash, Ubuntu Server, OpenSSH, ssh-keygen, envsubst e acesso root.
# Uso: sudo bash scripts/hardening-ssh.sh [--reverter]
# Requisito do trabalho atendido: R2.5
# Fonte externa: nenhuma

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly LAB_ENV="${REPO_DIR}/config/lab.env"
readonly TEMPLATE="${REPO_DIR}/infra/sshd/00-saas-hardening.conf.tmpl"
readonly PUBLIC_KEYS_DIR="${REPO_DIR}/infra/sshd/chaves-publicas"
readonly SSH_DROP_IN_DIR="/etc/ssh/sshd_config.d"
readonly SSH_DROP_IN="${SSH_DROP_IN_DIR}/00-saas-hardening.conf"
readonly BACKUP_ROOT="/var/backups/saas-ssh"

LAN_REDE=""
PORTA_SSH=""
USUARIOS_ADMIN=""
USUARIO_DEPLOY=""
DEPLOY_ORIGEM=""
ALLOW_USERS=""
USERS_ADMIN=()

# Confere uma rede CIDR para impedir que AllowUsers receba uma expressão inválida.
# Parâmetro: rede IPv4 seguida de prefixo.
validar_cidr() {
    local valor="$1"
    local endereco="${valor%/*}"
    local prefixo="${valor##*/}"
    local octeto
    local -a octetos

    [[ "${valor}" == */* ]] || return 1
    [[ "${endereco}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r -a octetos <<< "${endereco}"
    for octeto in "${octetos[@]}"; do
        (( 10#${octeto} <= 255 )) || return 1
    done
    [[ "${prefixo}" =~ ^([1-9]|[12][0-9]|3[0-2])$ ]]
}

# Confere uma origem IPv4 ou CIDR usada pela conta de deploy.
# Parâmetro: endereço IPv4 ou rede CIDR.
validar_origem() {
    local origem="$1"
    local endereco="${origem%/*}"
    local prefixo="${origem##*/}"
    local octeto
    local -a octetos

    [[ -z "${origem}" ]] && return 0
    if [[ "${origem}" == */* ]]; then
        [[ "${prefixo}" =~ ^([1-9]|[12][0-9]|3[0-2])$ ]] || return 1
    else
        endereco="${origem}"
    fi
    [[ "${endereco}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r -a octetos <<< "${endereco}"
    for octeto in "${octetos[@]}"; do
        (( 10#${octeto} <= 255 )) || return 1
    done
}

# Valida o nome usado em contas locais e em caminhos de chave pública.
# Parâmetro: nome de usuário POSIX esperado.
validar_usuario() {
    local usuario="$1"
    [[ "${usuario}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

# Carrega os parâmetros e verifica dependências antes de qualquer alteração.
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

    local required_vars=(LAN_REDE PORTA_SSH USUARIOS_ADMIN USUARIO_DEPLOY)
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
    if [[ ! "${PORTA_SSH}" =~ ^[1-9][0-9]*$ ]] || (( PORTA_SSH < 1 || PORTA_SSH > 65535)); then
        printf 'ERRO: PORTA_SSH deve estar entre 1 e 65535.\n' >&2
        exit 1
    fi
    if [[ "${PORTA_SSH}" == "22" ]]; then
        printf 'ERRO: PORTA_SSH deve ser uma porta diferente da porta 22.\n' >&2
        exit 1
    fi
    if [[ -n "${DEPLOY_ORIGEM:-}" ]]; then
        validar_origem "${DEPLOY_ORIGEM}" || {
            printf 'ERRO: DEPLOY_ORIGEM deve ser um IPv4 ou CIDR válido.\n' >&2
            exit 1
        }
    else
        DEPLOY_ORIGEM=""
    fi

    validar_usuario "${USUARIO_DEPLOY}" || {
        printf 'ERRO: USUARIO_DEPLOY contém um nome de usuário inválido.\n' >&2
        exit 1
    }
    if [[ ! -r "${TEMPLATE}" ]]; then
        printf 'ERRO: não encontrei infra/sshd/00-saas-hardening.conf.tmpl.\n' >&2
        exit 1
    fi
    if [[ ! -d "${PUBLIC_KEYS_DIR}" ]]; then
        printf 'ERRO: não encontrei infra/sshd/chaves-publicas.\n' >&2
        exit 1
    fi

    command -v sshd >/dev/null 2>&1 || {
        printf 'ERRO: o servidor OpenSSH não está instalado.\n' >&2
        exit 1
    }
    command -v envsubst >/dev/null 2>&1 || {
        printf 'ERRO: envsubst não está instalado. Instale gettext-base.\n' >&2
        exit 1
    }
    command -v ssh-keygen >/dev/null 2>&1 || {
        printf 'ERRO: ssh-keygen não está instalado.\n' >&2
        exit 1
    }
    command -v ss >/dev/null 2>&1 || {
        printf 'ERRO: ss não está instalado.\n' >&2
        exit 1
    }
}

# Converte a lista separada por vírgulas em contas válidas e únicas.
# Parâmetro: nenhum; usa USUARIOS_ADMIN carregado de lab.env.
montar_usuarios() {
    USERS_ADMIN=()
    local usuario
    local old_ifs="${IFS}"
    IFS=','
    read -r -a USERS_ADMIN <<< "${USUARIOS_ADMIN}"
    IFS="${old_ifs}"

    for usuario in "${USERS_ADMIN[@]}"; do
        usuario="${usuario//[[:space:]]/}"
        validar_usuario "${usuario}" || {
            printf 'ERRO: conta administrativa inválida em USUARIOS_ADMIN: %s\n' "${usuario}" >&2
            exit 1
        }
    done

    if ((${#USERS_ADMIN[@]} == 0)); then
        printf 'ERRO: USUARIOS_ADMIN não contém contas nominais.\n' >&2
        exit 1
    fi
}

# Monta AllowUsers antes de criar contas ou alterar o sshd.
# Parâmetro: nenhum; usa as contas administrativas e de deploy.
montar_allow_users() {
    local partes=()
    local usuario

    for usuario in "${USERS_ADMIN[@]}"; do
        usuario="${usuario//[[:space:]]/}"
        partes+=("${usuario}@${LAN_REDE}")
    done
    partes+=("${USUARIO_DEPLOY}@${LAN_REDE}")
    if [[ -n "${DEPLOY_ORIGEM}" ]]; then
        partes+=("${USUARIO_DEPLOY}@${DEPLOY_ORIGEM}")
    fi
    printf -v ALLOW_USERS '%s ' "${partes[@]}"
    ALLOW_USERS="${ALLOW_USERS% }"
}

# Verifica todas as chaves públicas antes de qualquer alteração no sistema.
# Nenhum parâmetro.
pre_verificar_chaves() {
    local usuario
    local chave
    local chave_dados

    for usuario in "${USERS_ADMIN[@]}" "${USUARIO_DEPLOY}"; do
        usuario="${usuario//[[:space:]]/}"
        chave="${PUBLIC_KEYS_DIR}/${usuario}.pub"
        if [[ ! -f "${chave}" || ! -r "${chave}" || ! -s "${chave}" ]]; then
            printf 'ERRO: falta chave pública para %s em %s.\n' "${usuario}" "${chave}" >&2
            exit 1
        fi
        if ! ssh-keygen -lf "${chave}" >/dev/null 2>&1; then
            printf 'ERRO: %s deve conter uma chave pública Ed25519.\n' "${chave}" >&2
            exit 1
        fi
        chave_dados="$(<"${chave}")"
        if [[ "${chave_dados}" != ssh-ed25519\ * ]]; then
            printf 'ERRO: %s deve conter uma chave pública Ed25519.\n' "${chave}" >&2
            exit 1
        fi
    done
}

# Cria contas nominais sem senha e instala a chave pública correspondente.
# Nenhum parâmetro.
criar_contas_e_chaves() {
    local usuario
    local chave
    local home

    for usuario in "${USERS_ADMIN[@]}" "${USUARIO_DEPLOY}"; do
        usuario="${usuario//[[:space:]]/}"
        if ! id "${usuario}" >/dev/null 2>&1; then
            # Sem definir uma senha, a conta nova fica sem autenticação local por senha.
            useradd --create-home --shell /bin/bash "${usuario}"
        fi
        home="$(getent passwd "${usuario}" | cut -d: -f6)"
        if [[ -z "${home}" || "${home}" == "/" ]]; then
            printf 'ERRO: não foi possível determinar o diretório pessoal de %s.\n' "${usuario}" >&2
            exit 1
        fi
        chave="${PUBLIC_KEYS_DIR}/${usuario}.pub"
        install -d -m 700 -o "${usuario}" -g "$(id -gn "${usuario}")" "${home}/.ssh"
        install -m 600 -o "${usuario}" -g "$(id -gn "${usuario}")" "${chave}" "${home}/.ssh/authorized_keys"
    done
}

# Preserva configuração atual e estado do serviço para reversão posterior.
# Retorna o caminho do backup pela variável global BACKUP_DIR.
criar_backup() {
    install -d -m 700 -o root -g root "${BACKUP_ROOT}"
    BACKUP_DIR="$(mktemp -d "${BACKUP_ROOT}/backup.XXXXXX")"
    chmod 700 "${BACKUP_DIR}"

    if [[ -f "${SSH_DROP_IN}" ]]; then
        cp -a -- "${SSH_DROP_IN}" "${BACKUP_DIR}/00-saas-hardening.conf"
    fi

    if systemctl is-enabled ssh.socket >/dev/null 2>&1; then
        printf 'socket_enabled=true\n' > "${BACKUP_DIR}/sshd-state"
    else
        printf 'socket_enabled=false\n' > "${BACKUP_DIR}/sshd-state"
    fi
    if systemctl is-enabled ssh.service >/dev/null 2>&1; then
        printf 'service_enabled=true\n' >> "${BACKUP_DIR}/sshd-state"
    else
        printf 'service_enabled=false\n' >> "${BACKUP_DIR}/sshd-state"
    fi
    if systemctl is-active ssh.service >/dev/null 2>&1; then
        printf 'service_active=true\n' >> "${BACKUP_DIR}/sshd-state"
    else
        printf 'service_active=false\n' >> "${BACKUP_DIR}/sshd-state"
    fi
    if systemctl is-active ssh.socket >/dev/null 2>&1; then
        printf 'socket_active=true\n' >> "${BACKUP_DIR}/sshd-state"
    else
        printf 'socket_active=false\n' >> "${BACKUP_DIR}/sshd-state"
    fi
}

# Renderiza somente as diretivas aprovadas e aplica o prefixo 00 exigido.
# Nenhum parâmetro.
renderizar_configuracao() {
    local rendered
    rendered="$(mktemp)"
    export PORTA_SSH ALLOW_USERS
    envsubst '${PORTA_SSH} ${ALLOW_USERS}' < "${TEMPLATE}" > "${rendered}"
    install -d -m 755 -o root -g root "${SSH_DROP_IN_DIR}"
    install -m 600 -o root -g root "${rendered}" "${SSH_DROP_IN}"
    rm -f -- "${rendered}"
}

# Seleciona o modo tradicional se o socket estiver ativo.
# Isso evita que o socket ignore Port para a diretiva solicitada.
# Nenhum parâmetro.
ajustar_ativacao_sshd() {
    if systemctl is-enabled ssh.socket >/dev/null 2>&1 \
        || systemctl is-active ssh.socket >/dev/null 2>&1; then
        # No Ubuntu moderno, ssh.socket pode controlar a porta antes de ler o Port.
        systemctl disable --now ssh.socket
        systemctl enable --now ssh.service
    else
        systemctl enable ssh.service
    fi
}

# Valida a configuração efetiva antes de reiniciar o serviço.
# Nenhum parâmetro.
validar_e_reiniciar() {
    sshd -t
    ajustar_ativacao_sshd
    systemctl restart ssh.service
}

# Confirma na tabela de sockets que a porta alta está ativa e a porta 22 não está.
# Nenhum parâmetro.
confirmar_portas() {
    local sockets
    local ssh_porta
    local porta22

    sockets="$(ss -H -tlnp)"
    ssh_porta="$(printf '%s\n' "${sockets}" | grep -E "[.:]${PORTA_SSH}[[:space:]]" || true)"
    porta22="$(printf '%s\n' "${sockets}" | grep -E "[.:]22[[:space:]]" || true)"

    if [[ -z "${ssh_porta}" ]]; then
        printf 'ERRO: o OpenSSH não confirmou escuta na porta %s.\n' "${PORTA_SSH}" >&2
        exit 1
    fi
    if [[ -n "${porta22}" ]]; then
        printf 'ERRO: a porta 22 continua escutando em uma associação TCP.\n' >&2
        exit 1
    fi

    printf 'Escuta confirmada em %s:\n%s\n' "${PORTA_SSH}" "${ssh_porta}"
    printf 'Porta 22 não encontrada em ss -tlnp.\n'
}

# Mostra somente os parâmetros que esta etapa altera.
# Nenhum parâmetro.
mostrar_sshd_efetivo() {
    sshd -T \
        | grep -E '^(port|permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|allowusers) '
}

# Restaura o último backup completo produzido por este script.
# Nenhum parâmetro.
reverter() {
    local latest
    local socket_enabled
    local service_enabled
    local service_active
    local socket_active
    if [[ ! -d "${BACKUP_ROOT}" ]]; then
        printf 'ERRO: não encontrei um backup anterior em %s.\n' "${BACKUP_ROOT}" >&2
        exit 1
    fi
    latest="$(find "${BACKUP_ROOT}" -mindepth 1 -maxdepth 1 -type d \
        -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)"
    if [[ -z "${latest}" || ! -f "${latest}/sshd-state" ]]; then
        printf 'ERRO: não encontrei um backup anterior em %s.\n' "${BACKUP_ROOT}" >&2
        exit 1
    fi

    if [[ -f "${latest}/00-saas-hardening.conf" ]]; then
        install -d -m 755 "${SSH_DROP_IN_DIR}"
        install -m 600 root:root "${latest}/00-saas-hardening.conf" "${SSH_DROP_IN}"
    else
        rm -f -- "${SSH_DROP_IN}"
    fi

    socket_enabled="$(grep -Fxq 'socket_enabled=true' "${latest}/sshd-state" && printf true || printf false)"
    service_enabled="$(grep -Fxq 'service_enabled=true' "${latest}/sshd-state" && printf true || printf false)"
    service_active="$(grep -Fxq 'service_active=true' "${latest}/sshd-state" && printf true || printf false)"
    socket_active="$(grep -Fxq 'socket_active=true' "${latest}/sshd-state" && printf true || printf false)"
    systemctl disable --now ssh.socket >/dev/null 2>&1 || true
    systemctl disable --now ssh.service >/dev/null 2>&1 || true
    if [[ "${socket_enabled}" == true ]]; then
        systemctl enable ssh.socket
    else
        systemctl disable ssh.socket >/dev/null 2>&1 || true
    fi
    if [[ "${service_enabled}" == true ]]; then
        systemctl enable ssh.service
    else
        systemctl disable ssh.service >/dev/null 2>&1 || true
    fi
    sshd -t
    if [[ "${socket_active}" == true ]]; then
        systemctl start ssh.socket
    fi
    if [[ "${service_active}" == true ]]; then
        systemctl start ssh.service
    fi
    printf 'Configuração SSH revertida a partir de %s.\n' "${latest}"
}

if (( $# > 1)); then
    printf 'Uso: sudo bash scripts/hardening-ssh.sh [--reverter]\n' >&2
    exit 1
fi

if [[ "${1:-}" == "--reverter" ]]; then
    if (( EUID != 0)); then
        printf 'ERRO: execute este script como root.\n' >&2
        exit 1
    fi
    reverter
    exit 0
fi
if [[ "${1:-}" != "" ]]; then
    printf 'Uso: sudo bash scripts/hardening-ssh.sh [--reverter]\n' >&2
    exit 1
fi

validar_ambiente
montar_usuarios
montar_allow_users
# Esta ordem impede qualquer criação de conta ou alteração de SSH sem todas as chaves públicas.
pre_verificar_chaves
criar_backup
criar_contas_e_chaves
renderizar_configuracao
validar_e_reiniciar
confirmar_portas
mostrar_sshd_efetivo
