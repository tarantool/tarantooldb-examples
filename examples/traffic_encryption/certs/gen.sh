#!/bin/bash

set -e

CA_PASS="pass"
CA_NAME="RootCA"
DAYS=36000

# Список имен хостов
HOSTNAMES=(
  "localhost"
  "tarantool-router-msk"
  "tarantool-storage-1-msk"
  "tarantool-storage-1-spb"
  "etcd1"
  "etcd2"
  "etcd3"
  "tcm"
)

BASE_DIR="$(dirname "$0")"
CA_DIR="$BASE_DIR/ca"
ETCD_DIR="$BASE_DIR/etcd"
TARANTOOL_DIR="$BASE_DIR/tarantool"
TCM_DIR="$BASE_DIR/tcm"

mkdir -p "$CA_DIR" "$ETCD_DIR" "$TARANTOOL_DIR" "$TCM_DIR"

# Создаем корневой сертификат
echo "Generating root CA..."
openssl genpkey -algorithm RSA -aes256 -out "$CA_DIR/ca-key.pem" -pass pass:$CA_PASS
openssl req -x509 -new -key "$CA_DIR/ca-key.pem" -out "$CA_DIR/root-ca.pem" -subj "/CN=$CA_NAME" -days $DAYS -passin pass:$CA_PASS

# Функция для создания сертификатов
# Аргументы: <common_name> <output_prefix> <output_dir>
generate_cert() {
  local cn="$1"
  local prefix="$2"
  local out_dir="$3"

  local san_config="tmp_san.cnf"

  # Создаем конфигурационный файл для SAN  
  cat > "$san_config" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[req_distinguished_name]
[v3_req]
subjectAltName = @alt_names
extendedKeyUsage = serverAuth, clientAuth
[alt_names]
EOF

  # Добавляем все хост-имена в конфигурационный файл
  local i=1
  for hostname in "${HOSTNAMES[@]}"; do
    echo "DNS.$i = $hostname" >> "$san_config"
    ((i++))
  done

  # Генерируем ключ
  openssl genpkey -algorithm RSA -out "$out_dir/${prefix}-key.pem"

  # CSR
  openssl req -new -key "$out_dir/${prefix}-key.pem" -out "${prefix}-csr.pem" -subj "/CN=$cn" -config "$san_config"

  # Создаем сертификат
  openssl x509 -req \
    -in "${prefix}-csr.pem" \
    -out "$out_dir/${prefix}.pem" \
    -CA "$CA_DIR/root-ca.pem" \
    -CAkey "$CA_DIR/ca-key.pem" \
    -CAcreateserial \
    -days $DAYS \
    -passin "pass:$CA_PASS" \
    -extensions v3_req \
    -extfile "$san_config"

  rm -f "${prefix}-csr.pem" "$san_config"
}

echo "Generating Tarantool certificates..."
generate_cert "tarantool" "server" "$TARANTOOL_DIR"
generate_cert "tarantool-client" "client" "$TARANTOOL_DIR"
generate_cert "tarantool-metrics" "metrics" "$TARANTOOL_DIR"

echo "Generating TCM certificates..."
generate_cert "tcm" "server" "$TCM_DIR"

echo "Generating etcd certificates..."
generate_cert "etcd-server" "server" "$ETCD_DIR"
generate_cert "etcd-peer" "peer" "$ETCD_DIR"
generate_cert "etcd-client" "client" "$ETCD_DIR"

chmod 666 "$CA_DIR"/*.pem
chmod 666 "$ETCD_DIR"/*.pem
chmod 666 "$TARANTOOL_DIR"/*.pem
chmod 666 "$TCM_DIR"/*.pem

echo ""
echo "All certificates generated successfully"
echo ""
echo "Structure:"
echo "ca/root-ca.pem"
echo "etcd/{client,peer,server}.{pem,-key.pem}"
echo "tarantool/{client,server,metrics}.{pem,-key.pem}"
echo "tcm/server.{pem,-key.pem}"
