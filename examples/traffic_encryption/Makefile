SHELL := /bin/bash

ifneq ($(shell command -v docker-compose version),)
    DOCKER_COMPOSE = docker-compose
endif

ifneq ($(shell docker compose version 2>/dev/null),)
    DOCKER_COMPOSE = docker compose
endif

ifndef DOCKER_COMPOSE
    $(error "Не найден docker-compose или docker compose")
endif

.SILENT: start
start:
	cd certs && ./gen.sh
	cp -a certs go/
	cp -a certs python/
	docker network create tarantooldb_network || true # not create if exists
	cd tools \
		&& $(DOCKER_COMPOSE) up -d --build \
		&& $(DOCKER_COMPOSE) exec -it tcm-1 bash -c "\
			tools/client/wait_etcd_ready.sh 45 https://etcd1:2379 /certs/ca/root-ca.pem /certs/etcd/client.pem /certs/etcd/client-key.pem \
			&& tools/client/wait_etcd_ready.sh 45 https://etcd2:2379 /certs/ca/root-ca.pem /certs/etcd/client.pem /certs/etcd/client-key.pem \
			&& tools/client/wait_etcd_ready.sh 45 https://etcd3:2379 /certs/ca/root-ca.pem /certs/etcd/client.pem /certs/etcd/client-key.pem \
			&& tt cluster publish 'https://etcd1:2379/tdb?ssl_ca_file=/certs/ca/root-ca.pem&ssl_cert_file=/certs/etcd/client.pem&ssl_key_file=/certs/etcd/client-key.pem' config.yml --force \
			&& tools/client/wait_config_ready.sh 25 'https://etcd1:2379/tdb?ssl_ca_file=/certs/ca/root-ca.pem&ssl_cert_file=/certs/etcd/client.pem&ssl_key_file=/certs/etcd/client-key.pem' \
			&& echo Load config done"
	cd cluster && $(DOCKER_COMPOSE) up -d --build

.PHONY: go
go:
	docker build -t traffic-encryption-go -f go/Dockerfile ./go
	docker run --network tarantooldb_network traffic-encryption-go

.PHONY: python
python:
	docker build -t traffic-encryption-python -f python/Dockerfile ./python
	docker run --network tarantooldb_network traffic-encryption-python

stop:
	cd cluster && $(DOCKER_COMPOSE) down
	cd tools && $(DOCKER_COMPOSE) down
	docker container prune -f
	docker network prune -f
