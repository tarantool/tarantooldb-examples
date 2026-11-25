#!/bin/bash

# Генерация самоподписанных сертификатов для HTTPS/mTLS адресов обработчика
# запроса. Вызывается из `make start`, файлы складываются в certs/

set -euo pipefail

DAYS=3650
CA_CN="tdb-worker-example-ca"
SERVER_CN="tdb-worker"
CLIENT_CN="tdb-worker-client"

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$BASE_DIR"

# Корневой (самоподписанный) CA — им подписываются серверный и клиентский
# сертификаты, и он же служит доверенным CA для mTLS.
openssl genpkey -algorithm RSA -out "$BASE_DIR/ca.key" -pkeyopt rsa_keygen_bits:2048
openssl req -x509 -new -key "$BASE_DIR/ca.key" -out "$BASE_DIR/ca.crt" \
    -subj "/CN=$CA_CN" -days "$DAYS" -sha256

generate_cert() {
    local cn="$1"
    local prefix="$2"
    local ext="$3"
    local san="$4"

    local san_conf
    san_conf="$(mktemp)"

    cat > "$san_conf" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[req_distinguished_name]
[v3_req]
subjectAltName = @alt_names
extendedKeyUsage = $ext
[alt_names]
$san
EOF

    openssl genpkey -algorithm RSA -out "$BASE_DIR/${prefix}.key" -pkeyopt rsa_keygen_bits:2048
    openssl req -new -key "$BASE_DIR/${prefix}.key" -out "$san_conf.csr" -subj "/CN=$cn"
    openssl x509 -req -in "$san_conf.csr" -out "$BASE_DIR/${prefix}.crt" \
        -CA "$BASE_DIR/ca.crt" -CAkey "$BASE_DIR/ca.key" -CAcreateserial \
        -days "$DAYS" -sha256 -extensions v3_req -extfile "$san_conf"

    rm -f "$san_conf" "$san_conf.csr"
}

# Серверный сертификат узла-обработчика. В subjectAltName перечислены адреса,
# по которым к обработчику обращаются извне и из TCM.
generate_cert \
    "$SERVER_CN" "server" "serverAuth" \
    "DNS.1 = worker-1
DNS.2 = worker-2
DNS.3 = localhost
IP.1 = 127.0.0.1
IP.2 = 0.0.0.0"

# Клиентский сертификат — им TCM (и curl) представляются при включённом mTLS.
generate_cert \
    "$CLIENT_CN" "client" "clientAuth" \
    "DNS.1 = localhost
IP.1 = 127.0.0.1"

# Закрытый ключ TCM (RSA, PKCS#1) для подписи публикуемых конфигураций.
# Требуется начиная с TCM 1.12.0. Формат PKCS#1 задаётся флагом `-traditional`,
# так как OpenSSL 3.x по умолчанию создаёт ключ в формате PKCS#8.
openssl genrsa -traditional -out "$BASE_DIR/tcm-signature.pem" 2048

# Ключ шифрования TCM (AES-256, ровно 32 байта) для шифрования секретов.
openssl rand -out "$BASE_DIR/tcm-encryption.key" 32

chmod 0644 "$BASE_DIR"/*.crt "$BASE_DIR"/*.key "$BASE_DIR"/*.srl
chmod 0600 "$BASE_DIR"/tcm-signature.pem "$BASE_DIR"/tcm-encryption.key

echo ""
echo "Сертификаты и ключи сгенерированы в $BASE_DIR:"
echo "  ca.crt / ca.key           — корневой CA (доверие для mTLS)"
echo "  server.crt / server.key   — сертификат узла-обработчика"
echo "  client.crt / client.key   — клиентский сертификат (mTLS)"
echo "  tcm-signature.pem         — ключ TCM для подписи конфигураций (RSA PKCS#1)"
echo "  tcm-encryption.key        — ключ TCM для шифрования секретов (32 байта)"
