#!/bin/bash

# Список имен хостов
HOSTNAMES=("localhost" "tarantool-router" "tarantool-storage1" "tarantool-storage2" "tarantool-storage3" "tarantool-storage4")

# Пароль для корневого сертификата
CA_PASS="pass"

# Создаем корневой сертификат
openssl genpkey -algorithm RSA -aes256 -out ca-key.pem -pass pass:$CA_PASS
openssl req -x509 -new -key ca-key.pem -out ca-cert.pem -subj "/CN=RootCA" -days 36000 -passin pass:$CA_PASS

# Функция для создания сертификатов
generate_certificates() {
	local san_config="san.cnf"

	# Создаем конфигурационный файл для SAN
	echo "[req]" > $san_config
	echo "distinguished_name = req_distinguished_name" >> $san_config
	echo "req_extensions = v3_req" >> $san_config
	echo "[req_distinguished_name]" >> $san_config
	echo "[v3_req]" >> $san_config
	echo "subjectAltName = @alt_names" >> $san_config
	echo "[alt_names]" >> $san_config

	# Добавляем все хост-имена в конфигурационный файл
	local i=1
	for hostname in "${HOSTNAMES[@]}"; do
	echo "DNS.$i = $hostname" >> $san_config
	((i++))
	done

	# Создаем сертификат для сервера
	openssl genpkey -algorithm RSA -out server-key.pem
	openssl req -new -key server-key.pem -out server-csr.pem -subj "/CN=${HOSTNAMES[0]}" -config $san_config
	openssl x509 -req -in server-csr.pem -out server-cert.pem -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -days 36000 -passin pass:$CA_PASS -extensions v3_req -extfile $san_config
	rm server-csr.pem

	# Создаем сертификат для клиента
	openssl genpkey -algorithm RSA -out client-key.pem
	openssl req -new -key client-key.pem -out client-csr.pem -subj "/CN=${HOSTNAMES[0]}" -config $san_config
	openssl x509 -req -in client-csr.pem -out client-cert.pem -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -days 36000 -passin pass:$CA_PASS -extensions v3_req -extfile $san_config
	rm client-csr.pem

	# Удаляем временный конфигурационный файл
	rm $san_config
}

generate_certificates

# Для передачи в Docker compose для простоты затираем разрешения (там другой пользователь используется)
chmod 666 *.pem
echo "Certificates generated successfully"
