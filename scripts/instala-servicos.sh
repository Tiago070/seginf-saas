#!/usr/bin/env bash
# Nome: instala-servicos.sh
# Finalidade: Instalar Nginx e PostgreSQL com HTTPS e acesso ao banco restrito à LAN.
# Autor: DEFINIR
# Data: 18/11/2026
# Requisitos: Bash, Ubuntu Server, acesso ao config/lab.env e à Internet pela WAN.
# Uso: sudo bash scripts/instala-servicos.sh
# Requisito do trabalho atendido: R2.1
# Fonte externa: nenhuma

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly LAB_ENV="${REPO_DIR}/config/lab.env"
readonly SECRET_FILE="/root/.saas-db-senha"
readonly NGINX_SITE="/etc/nginx/sites-available/saas-lab"
readonly NGINX_LINK="/etc/nginx/sites-enabled/saas-lab"
readonly WEB_ROOT="/var/www/saas-lab"

# Valida endereços usados em configurações que serão lidas por serviços privilegiados.
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

# Confere a máscara da rede permitida pelo PostgreSQL antes de gravá-la no pg_hba.conf.
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

if (( EUID != 0 )); then
    printf 'Execute este script como root, por exemplo: sudo bash scripts/instala-servicos.sh\n' >&2
    exit 1
fi
if [[ ! -r "${LAB_ENV}" ]]; then
    printf 'ERRO: não encontrei config/lab.env no repositório.\n' >&2
    exit 1
fi

# A configuração central mantém os endereços, portas e nomes de serviço
# consistentes com Netplan e com a documentação do laboratório.
source "${LAB_ENV}"
required_vars=(
    IFACE_LAN LAN_IP_SERVIDOR LAN_REDE PORTA_HTTP PORTA_HTTPS PORTA_DB
    TLS_COMMON_NAME TLS_CERT_DAYS TLS_CERT_PATH TLS_KEY_PATH DB_NAME DB_USER
)
for variable_name in "${required_vars[@]}"; do
    if [[ -z "${!variable_name:-}" || "${!variable_name}" == "DEFINIR" ]]; then
        printf 'ERRO: defina %s em config/lab.env antes de continuar.\n' "${variable_name}" >&2
        exit 1
    fi
done

if [[ ! "${IFACE_LAN}" =~ ^[[:alnum:]_.:-]+$ ]] || ! valid_ipv4 "${LAN_IP_SERVIDOR}"; then
    printf 'ERRO: confira IFACE_LAN e LAN_IP_SERVIDOR em config/lab.env.\n' >&2
    exit 1
fi
if ! valid_cidr "${LAN_REDE}"; then
    printf 'ERRO: LAN_REDE deve ser uma rede IPv4 em formato CIDR.\n' >&2
    exit 1
fi
if [[ ! "${PORTA_HTTP}" =~ ^[1-9][0-9]*$ || ! "${PORTA_HTTPS}" =~ ^[1-9][0-9]*$ || ! "${PORTA_DB}" =~ ^[1-9][0-9]*$ ]]; then
    printf 'ERRO: confira PORTA_HTTP, PORTA_HTTPS e PORTA_DB em config/lab.env.\n' >&2
    exit 1
fi
if (( PORTA_HTTP > 65535 || PORTA_HTTPS > 65535 || PORTA_DB > 65535 )); then
    printf 'ERRO: as portas devem estar entre 1 e 65535.\n' >&2
    exit 1
fi
if [[ "${PORTA_HTTP}" == "${PORTA_HTTPS}" || "${PORTA_HTTP}" == "${PORTA_DB}" || "${PORTA_HTTPS}" == "${PORTA_DB}" ]]; then
    printf 'ERRO: HTTP, HTTPS e PostgreSQL precisam usar portas diferentes.\n' >&2
    exit 1
fi
if [[ ! "${DB_NAME}" =~ ^[a-z_][a-z0-9_]{0,62}$ || ! "${DB_USER}" =~ ^[a-z_][a-z0-9_]{0,62}$ ]]; then
    printf 'ERRO: DB_NAME e DB_USER devem usar letras minúsculas, números e sublinhado.\n' >&2
    exit 1
fi
if [[ ! "${TLS_COMMON_NAME}" =~ ^[[:alnum:].-]+$ ]]; then
    printf 'ERRO: TLS_COMMON_NAME deve ser um nome DNS simples ou hostname.\n' >&2
    exit 1
fi
if [[ ! "${TLS_CERT_DAYS}" =~ ^[1-9][0-9]*$ ]]; then
    printf 'ERRO: TLS_CERT_DAYS deve ser um inteiro positivo.\n' >&2
    exit 1
fi
if [[ ! "${TLS_CERT_PATH}" =~ ^/etc/ssl/certs/[[:alnum:]_.-]+$ || ! "${TLS_KEY_PATH}" =~ ^/etc/ssl/private/[[:alnum:]_.-]+$ ]]; then
    printf 'ERRO: os caminhos do certificado e da chave devem estar nos diretórios /etc/ssl/certs e /etc/ssl/private.\n' >&2
    exit 1
fi

if ! ip -o -4 addr show dev "${IFACE_LAN}" | grep -Fq "${LAN_IP_SERVIDOR}/"; then
    printf 'ERRO: %s não está configurada com %s. Execute primeiro scripts/aplica-rede.sh.\n' "${IFACE_LAN}" "${LAN_IP_SERVIDOR}" >&2
    exit 1
fi
if ! command -v apt-get >/dev/null 2>&1; then
    printf 'ERRO: apt-get não está disponível; este script requer Ubuntu.\n' >&2
    exit 1
fi

# OpenSSL é necessário para gerar o certificado e a senha; instalar os pacotes
# antes de usá-lo também torna a primeira execução em uma VM limpa funcional.
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx postgresql openssl
systemctl enable --now postgresql
systemctl enable nginx

# O certificado é autoassinado para o laboratório; não substituímos um par
# válido já existente para manter a operação idempotente.
backup_dir="$(mktemp -d /var/backups/saas-services.XXXXXX)"
chmod 700 "${backup_dir}"
printf 'Backup das configurações substituídas: %s\n' "${backup_dir}"
certificate_tmp=""
key_tmp=""
nginx_config=""
pg_hba_tmp=""
# Remove temporários sem esconder o código de saída da etapa que falhou.
# Parâmetro: nenhum; mantém o código de saída recebido pelo trap EXIT.
cleanup_temporary_files() {
    local status=$?
    trap - EXIT
    rm -f -- "${certificate_tmp}" "${key_tmp}" "${nginx_config}" "${pg_hba_tmp}"
    exit "${status}"
}
trap cleanup_temporary_files EXIT
for original_file in "${TLS_CERT_PATH}" "${TLS_KEY_PATH}" "${NGINX_SITE}" "${WEB_ROOT}/index.html"; do
    if [[ -f "${original_file}" ]]; then
        cp -a -- "${original_file}" "${backup_dir}/$(basename -- "${original_file}").previous"
    fi
done
if [[ -L "${NGINX_LINK}" ]]; then
    cp -a -- "${NGINX_LINK}" "${backup_dir}/nginx-lab-link.previous"
fi
mkdir -p -- "$(dirname -- "${TLS_CERT_PATH}")" "$(dirname -- "${TLS_KEY_PATH}")"
if [[ -f "${TLS_CERT_PATH}" && -f "${TLS_KEY_PATH}" ]]; then
    if ! openssl x509 -in "${TLS_CERT_PATH}" -noout -checkend 0 >/dev/null 2>&1; then
        rm -f -- "${TLS_CERT_PATH}" "${TLS_KEY_PATH}"
    elif ! cmp -s \
        <(openssl x509 -in "${TLS_CERT_PATH}" -pubkey -noout) \
        <(openssl pkey -in "${TLS_KEY_PATH}" -pubout); then
        printf 'ERRO: o certificado e a chave existentes não correspondem; os arquivos foram preservados.\n' >&2
        exit 1
    else
        chmod 644 "${TLS_CERT_PATH}"
        chmod 600 "${TLS_KEY_PATH}"
    fi
elif [[ -e "${TLS_CERT_PATH}" || -e "${TLS_KEY_PATH}" ]]; then
    rm -f -- "${TLS_CERT_PATH}" "${TLS_KEY_PATH}"
fi
if [[ ! -f "${TLS_CERT_PATH}" || ! -f "${TLS_KEY_PATH}" ]]; then
    certificate_tmp="$(mktemp)"
    key_tmp="$(mktemp)"
    openssl req -x509 -nodes -days "${TLS_CERT_DAYS}" -newkey rsa \
        -keyout "${key_tmp}" -out "${certificate_tmp}" \
        -subj "/CN=${TLS_COMMON_NAME}"
    install -o root -g root -m 644 "${certificate_tmp}" "${TLS_CERT_PATH}"
    install -o root -g root -m 600 "${key_tmp}" "${TLS_KEY_PATH}"
    rm -f -- "${certificate_tmp}" "${key_tmp}"
    certificate_tmp=""
    key_tmp=""
fi

# Evitar sobrescrever sites de outros serviços: o laboratório instala somente
# seu próprio site e desativa a página padrão após validar a nova configuração.
shopt -s nullglob
for enabled_site in /etc/nginx/sites-enabled/*; do
    case "${enabled_site}" in
        /etc/nginx/sites-enabled/default|/etc/nginx/sites-enabled/saas-lab)
            ;;
        *)
            printf 'ERRO: site Nginx não previsto habilitado: %s. Revise-o antes de continuar.\n' "${enabled_site}" >&2
            exit 1
            ;;
    esac
done
if [[ -e "${NGINX_LINK}" && ! -L "${NGINX_LINK}" ]]; then
    printf 'ERRO: %s existe e não é um link simbólico; revise antes de continuar.\n' "${NGINX_LINK}" >&2
    exit 1
fi
if [[ -e /etc/nginx/sites-enabled/default && ! -L /etc/nginx/sites-enabled/default ]]; then
    printf 'ERRO: /etc/nginx/sites-enabled/default não é um link simbólico; revise antes de continuar.\n' >&2
    exit 1
fi
if [[ -L /etc/nginx/sites-enabled/default ]]; then
    cp -a -- /etc/nginx/sites-enabled/default "${backup_dir}/nginx-default-link.previous"
fi

mkdir -p -- "${WEB_ROOT}"
cat > "${WEB_ROOT}/index.html" <<'HTML'
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Laboratório SaaS</title>
</head>
<body>
  <main>
    <h1>Laboratório SaaS</h1>
    <p>Serviço HTTPS de demonstração da Etapa 2.</p>
  </main>
</body>
</html>
HTML
chmod 644 "${WEB_ROOT}/index.html"

nginx_config="$(mktemp)"
cat > "${nginx_config}" <<NGINX
server {
    listen ${PORTA_HTTP};
    server_name _;
    return 301 https://\$host:${PORTA_HTTPS}\$request_uri;
}

server {
    listen ${PORTA_HTTPS} ssl;
    server_name _;

    ssl_certificate ${TLS_CERT_PATH};
    ssl_certificate_key ${TLS_KEY_PATH};

    root ${WEB_ROOT};
    index index.html;
}
NGINX
install -o root -g root -m 644 "${nginx_config}" "${NGINX_SITE}"
rm -f -- "${nginx_config}"
nginx_config=""
ln -sfn -- ../sites-available/saas-lab "${NGINX_LINK}"
if [[ -L /etc/nginx/sites-enabled/default ]]; then
    rm -f -- /etc/nginx/sites-enabled/default
fi
nginx -t

# Guardar os arquivos originais antes de ALTER SYSTEM ou da política de acesso
# evita que o backup contenha já os valores novos.
postgres_hba="$(runuser -u postgres -- psql --set=ON_ERROR_STOP=1 --dbname=postgres --tuples-only --no-align --command='SHOW hba_file;')"
postgres_data="$(runuser -u postgres -- psql --set=ON_ERROR_STOP=1 --dbname=postgres --tuples-only --no-align --command='SHOW data_directory;')"
postgres_auto="${postgres_data}/postgresql.auto.conf"
if [[ ! -f "${postgres_hba}" || ! -d "${postgres_data}" ]]; then
    printf 'ERRO: não foi possível localizar os arquivos de configuração do PostgreSQL.\n' >&2
    exit 1
fi
cp -a -- "${postgres_hba}" "${backup_dir}/pg_hba.conf.previous"
if [[ -f "${postgres_auto}" ]]; then
    cp -a -- "${postgres_auto}" "${backup_dir}/postgresql.auto.conf.previous"
fi

# ALTER SYSTEM mantém bind, porta e SCRAM na configuração gerenciada pelo
# PostgreSQL; pg_hba.conf limita autenticação por senha à rede LAN do laboratório.
runuser -u postgres -- psql --set=ON_ERROR_STOP=1 --dbname=postgres \
    --command="ALTER SYSTEM SET listen_addresses = '${LAN_IP_SERVIDOR}';"
runuser -u postgres -- psql --set=ON_ERROR_STOP=1 --dbname=postgres \
    --command="ALTER SYSTEM SET port = '${PORTA_DB}';"
runuser -u postgres -- psql --set=ON_ERROR_STOP=1 --dbname=postgres \
    --command="ALTER SYSTEM SET password_encryption = 'scram-sha-256';"

pg_hba_tmp="$(mktemp)"
cat > "${pg_hba_tmp}" <<HBA
# Conexões administrativas locais usam peer para não armazenar credenciais.
local all postgres peer
local all all peer
# Somente a rede LAN pode autenticar a aplicação por senha SCRAM.
host ${DB_NAME} ${DB_USER} ${LAN_REDE} scram-sha-256
HBA
install -o postgres -g postgres -m 640 "${pg_hba_tmp}" "${postgres_hba}"
rm -f -- "${pg_hba_tmp}"
pg_hba_tmp=""

systemctl restart postgresql
listen_addresses="$(runuser -u postgres -- psql --set=ON_ERROR_STOP=1 --dbname=postgres --tuples-only --no-align --command='SHOW listen_addresses;')"
configured_port="$(runuser -u postgres -- psql --set=ON_ERROR_STOP=1 --dbname=postgres --tuples-only --no-align --command='SHOW port;')"
if [[ "${listen_addresses}" != "${LAN_IP_SERVIDOR}" || "${configured_port}" != "${PORTA_DB}" ]]; then
    printf 'ERRO: PostgreSQL não confirmou o endereço e a porta configurados.\n' >&2
    exit 1
fi

# A senha é gerada uma única vez e guardada somente em /root; uma nova execução
# reutiliza o arquivo para que a credencial da conta de exemplo não mude.
if [[ -e "${SECRET_FILE}" ]]; then
    if [[ -L "${SECRET_FILE}" ]]; then
        printf 'ERRO: %s é um link simbólico; preserve-o e investigue antes de continuar.\n' "${SECRET_FILE}" >&2
        exit 1
    fi
    if [[ ! -s "${SECRET_FILE}" ]]; then
        printf 'ERRO: %s existe, mas está vazio; preserve-o e investigue antes de continuar.\n' "${SECRET_FILE}" >&2
        exit 1
    fi
    chown root:root "${SECRET_FILE}"
    chmod 600 "${SECRET_FILE}"
    db_password="$(<"${SECRET_FILE}")"
else
    db_password="$(openssl rand -hex 32)"
    umask 077
    printf '%s\n' "${db_password}" > "${SECRET_FILE}"
    chmod 600 "${SECRET_FILE}"
fi
if [[ ! "${db_password}" =~ ^[a-f0-9]{64}$ ]]; then
    printf 'ERRO: o arquivo de senha não contém o formato esperado; não foi alterado.\n' >&2
    exit 1
fi

role_exists="$(runuser -u postgres -- psql --set=ON_ERROR_STOP=1 --dbname=postgres --tuples-only --no-align --command="SELECT 1 FROM pg_roles WHERE rolname = '${DB_USER}';")"
if [[ "${role_exists}" == "1" ]]; then
    runuser -u postgres -- psql --set=ON_ERROR_STOP=1 --dbname=postgres <<SQL
ALTER ROLE ${DB_USER} WITH LOGIN PASSWORD '${db_password}';
SQL
else
    runuser -u postgres -- psql --set=ON_ERROR_STOP=1 --dbname=postgres <<SQL
CREATE ROLE ${DB_USER} LOGIN PASSWORD '${db_password}';
SQL
fi
database_exists="$(runuser -u postgres -- psql --set=ON_ERROR_STOP=1 --dbname=postgres --tuples-only --no-align --command="SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}';")"
if [[ "${database_exists}" != "1" ]]; then
    runuser -u postgres -- createdb --owner="${DB_USER}" "${DB_NAME}"
else
    runuser -u postgres -- psql --set=ON_ERROR_STOP=1 --dbname=postgres \
        --command="ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};"
fi

systemctl restart nginx
systemctl is-active --quiet nginx
systemctl is-active --quiet postgresql

printf 'Serviços ativos: Nginx HTTPS em %s e PostgreSQL em %s:%s.\n' \
    "${PORTA_HTTPS}" "${LAN_IP_SERVIDOR}" "${PORTA_DB}"
printf 'Redirecionamento HTTP configurado na porta %s.\n' "${PORTA_HTTP}"
printf 'Senha da conta de exemplo guardada somente em %s com modo 600.\n' "${SECRET_FILE}"
