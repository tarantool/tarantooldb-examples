#!/bin/sh
set -e

# LDAPS: подключает серверный сертификат AD, подписанный CA примера
# (certs/ad/server.pem из certs/gen.sh). Samba слушает ldaps:// на 636.
#
# Samba требует, чтобы приватный ключ TLS принадлежал root и имел права 0600
# (защита от CVE-2013-4476), поэтому сертификаты копируются из монтирования
# /certs во внутреннее хранилище Samba, а не подключаются напрямую.
mkdir -p /var/lib/samba/private/tls
install -m 0644 /certs/ca/root-ca.pem /var/lib/samba/private/tls/ca.pem
install -m 0644 /certs/ad/server.pem /var/lib/samba/private/tls/cert.pem
install -m 0600 /certs/ad/server-key.pem /var/lib/samba/private/tls/key.pem

sed -e '/^\[global\]/a\\ttls certfile = /var/lib/samba/private/tls/cert.pem\n\ttls keyfile = /var/lib/samba/private/tls/key.pem\n\ttls cafile = /var/lib/samba/private/tls/ca.pem' -i /etc/samba/smb.conf
