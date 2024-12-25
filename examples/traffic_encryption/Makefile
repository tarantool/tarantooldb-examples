SHELL := /bin/bash

.SILENT: start
start:
	cd certs && ./gen.sh
	cp -a certs go/
	cp -a certs python/
	docker network create tarantooldb_network || true # not create if exists
	cd tools \
		&& docker compose up -d --build \
		&& docker compose exec -it tcm-1 bash -c "\
			tools/client/wait_etcd_ready.sh 15 http://etcd1:2379 \
			&& tools/client/wait_etcd_ready.sh 15 http://etcd2:2379 \
			&& tools/client/wait_etcd_ready.sh 15 http://etcd3:2379 \
			&& tt cluster publish http://etcd1:2379/tdb config.yml --force \
			&& tools/client/wait_config_ready.sh 25 http://etcd1:2379/tdb \
			&& echo Load config done"
	cd cluster && docker compose up -d --build

.PHONY: go
go:
	docker build -t traffic-encryption-go -f go/Dockerfile ./go
	docker run -it --network tarantooldb_network traffic-encryption-go

.PHONY: python
python:
	docker build -t traffic-encryption-python -f python/Dockerfile ./python
	docker run -it --network tarantooldb_network traffic-encryption-python

stop:
	docker rm $(docker ps -a -q --filter "ancestor=tranffic-encryption-go") || true ## not rm if not exists
	docker rm $(docker ps -a -q --filter "ancestor=tranffic-encryption-python") || true ## not rm if not exists
	cd cluster && docker compose down
	cd tools && docker compose down
	docker container prune -f
	docker network prune -f
