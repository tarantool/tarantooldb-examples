#!/bin/bash

set -e

CA_PASS="pass"
CA_NAME="RootCA"
DAYS=36000

# Имена ldap-обработчиков из workers/docker-compose.yml — попадают в SAN сертификата
HOSTNAMES=(
  "ldap-worker-openldap"
  "ldap-worker-openldap-2"
  "ldap-worker-ad"
)

BASE_DIR="$(dirname "$0")"
CA_DIR="$BASE_DIR/ca"
WORKER_DIR="$BASE_DIR/worker"
ROUTER_DIR="$BASE_DIR/router"
CLIENT_DIR="$BASE_DIR/client"

mkdir -p "$CA_DIR" "$WORKER_DIR" "$ROUTER_DIR" "$CLIENT_DIR"

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

# Серверный сертификат роутера: SAN — имя контейнера роутера и localhost
# (Go-клиент подключается к localhost:3301)
cat > tmp_san.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[req_distinguished_name]
[v3_req]
subjectAltName = @alt_names
extendedKeyUsage = serverAuth, clientAuth
[alt_names]
DNS.1 = tarantool-router
DNS.2 = localhost
EOF

echo "Generating router server certificate..."
openssl genpkey -algorithm RSA -out "$ROUTER_DIR/server-key.pem"
openssl req -new -key "$ROUTER_DIR/server-key.pem" -out server-csr.pem -subj "/CN=tarantool-router" -config tmp_san.cnf
openssl x509 -req \
  -in server-csr.pem \
  -out "$ROUTER_DIR/server.pem" \
  -CA "$CA_DIR/root-ca.pem" \
  -CAkey "$CA_DIR/ca-key.pem" \
  -CAcreateserial \
  -days $DAYS \
  -passin pass:$CA_PASS \
  -extensions v3_req \
  -extfile tmp_san.cnf

rm -f server-csr.pem tmp_san.cnf

chmod 666 "$ROUTER_DIR"/*.pem

# Клиентский сертификат: им предъявляется mTLS и к роутеру (Go-клиент),
# и к LDAP-обработчикам (роутер, worker_client_cert_file роли tdb_ldap_auth)
cat > tmp_san.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[req_distinguished_name]
[v3_req]
subjectAltName = @alt_names
extendedKeyUsage = serverAuth, clientAuth
[alt_names]
DNS.1 = client
EOF

echo "Generating client certificate..."
openssl genpkey -algorithm RSA -out "$CLIENT_DIR/client-key.pem"
openssl req -new -key "$CLIENT_DIR/client-key.pem" -out client-csr.pem -subj "/CN=client" -config tmp_san.cnf
openssl x509 -req \
  -in client-csr.pem \
  -out "$CLIENT_DIR/client.pem" \
  -CA "$CA_DIR/root-ca.pem" \
  -CAkey "$CA_DIR/ca-key.pem" \
  -CAcreateserial \
  -days $DAYS \
  -passin pass:$CA_PASS \
  -extensions v3_req \
  -extfile tmp_san.cnf

rm -f client-csr.pem tmp_san.cnf

chmod 666 "$CLIENT_DIR"/*.pem

echo ""
echo "All certificates generated successfully"
echo ""
echo "Structure:"
echo "ca/root-ca.pem           — CA (worker_ca_file роли tdb_ldap_auth, ssl_ca_file слушателя роутера и обработчиков)"
echo "worker/server.pem        — сертификат LDAP-обработчиков"
echo "worker/server-key.pem    — ключ LDAP-обработчиков"
echo "router/server.pem        — сертификат роутера (SSL-слушатель iproto)"
echo "router/server-key.pem    — ключ роутера"
echo "client/client.pem        — клиентский сертификат (Go-клиент и роутер в mTLS)"
echo "client/client-key.pem    — ключ клиентского сертификата"
