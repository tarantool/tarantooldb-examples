#!/bin/bash

set -e

CA_PASS="pass"
CA_NAME="RootCA"
DAYS=36000

# Имена ldap-обработчиков из workers/docker-compose.yml — попадают в SAN сертификата
HOSTNAMES=(
  "ldap-worker-openldap"
  "ldap-worker-ad"
)

BASE_DIR="$(dirname "$0")"
CA_DIR="$BASE_DIR/ca"
WORKER_DIR="$BASE_DIR/worker"

mkdir -p "$CA_DIR" "$WORKER_DIR"

echo "Generating root CA..."
openssl genpkey -algorithm RSA -aes256 -out "$CA_DIR/ca-key.pem" -pass pass:$CA_PASS
openssl req -x509 -new -key "$CA_DIR/ca-key.pem" -out "$CA_DIR/root-ca.pem" -subj "/CN=$CA_NAME" -days $DAYS -passin pass:$CA_PASS

# Конфигурационный файл для SAN
cat > tmp_san.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[req_distinguished_name]
[v3_req]
subjectAltName = @alt_names
extendedKeyUsage = serverAuth, clientAuth
[alt_names]
EOF

local_i=1
for hostname in "${HOSTNAMES[@]}"; do
  echo "DNS.$local_i = $hostname" >> tmp_san.cnf
  local_i=$((local_i + 1))
done

echo "Generating ldap-worker server certificate..."
openssl genpkey -algorithm RSA -out "$WORKER_DIR/server-key.pem"
openssl req -new -key "$WORKER_DIR/server-key.pem" -out server-csr.pem -subj "/CN=ldap-worker" -config tmp_san.cnf
openssl x509 -req \
  -in server-csr.pem \
  -out "$WORKER_DIR/server.pem" \
  -CA "$CA_DIR/root-ca.pem" \
  -CAkey "$CA_DIR/ca-key.pem" \
  -CAcreateserial \
  -days $DAYS \
  -passin pass:$CA_PASS \
  -extensions v3_req \
  -extfile tmp_san.cnf

rm -f server-csr.pem tmp_san.cnf

chmod 666 "$CA_DIR"/*.pem
chmod 666 "$WORKER_DIR"/*.pem

echo ""
echo "All certificates generated successfully"
echo ""
echo "Structure:"
echo "ca/root-ca.pem           — CA (worker_ca_file роли tdb_ldap_auth)"
echo "worker/server.pem        — сертификат LDAP-обработчиков"
echo "worker/server-key.pem    — ключ LDAP-обработчиков"
