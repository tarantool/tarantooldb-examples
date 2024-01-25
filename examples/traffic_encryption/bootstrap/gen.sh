# OpenSSL 3.2.0 23 Nov 2023 (Library: OpenSSL 3.2.0 23 Nov 2023)

# создаем корневой сертификат
openssl genpkey -algorithm RSA -aes256 -out ca-key.pem  -pass pass:pass
openssl req -x509 -new -key ca-key.pem -out ca-cert.pem -subj "/CN=localhost" -days 36000 -passin pass:pass

# создаем сертификат для сервера
openssl genpkey -algorithm RSA -aes256 -pass pass:12345 -out server-key.pem
openssl req -new -key server-key.pem -out server-csr.pem -subj "/CN=localhost" -passin pass:12345
openssl x509 -req -in server-csr.pem -out server-cert.pem -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -days 36000 -passin pass:pass

# создаем сертификат для клиента
openssl genpkey -algorithm RSA -aes256 -pass pass:54321 -out client-key.pem
openssl req -new -key client-key.pem -out client-csr.pem -subj "/CN=localhost" -passin pass:54321
openssl x509 -req -in client-csr.pem -out client-cert.pem -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -days 36000 -passin pass:pass
