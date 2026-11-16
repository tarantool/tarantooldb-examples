#!/bin/sh
set -e

# Пользователь и группа для примера ldap_auth; || true — идемпотентность.
samba-tool user create bob 'BobPassw0rd!' || true
samba-tool group add tdb-writers || true
samba-tool group addmembers tdb-writers bob || true
