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
	bash certs/gen.sh
	docker network create tarantooldb_network
	cd tools \
		&& $(DOCKER_COMPOSE) up -d \
		&& $(DOCKER_COMPOSE) exec etcd etcdctl endpoint health \
		&& $(DOCKER_COMPOSE) run --rm tt-tools /bin/sh -c "\
			tools/client/wait_etcd_ready.sh 15 http://etcd:2379 \
			&& tt cluster publish http://etcd:2379/tdb config.yml --force \
			&& echo Cluster config published" \
		&& $(DOCKER_COMPOSE) exec -T etcd etcdctl put /tdb-workers/tdb/instances/127.0.0.1/ldap-worker-openldap < ../workers/openldap-worker.yml \
		&& $(DOCKER_COMPOSE) exec -T etcd etcdctl put /tdb-workers/tdb/instances/127.0.0.1/ldap-worker-openldap-2 < ../workers/openldap-worker-2.yml \
		&& $(DOCKER_COMPOSE) exec -T etcd etcdctl put /tdb-workers/tdb/instances/127.0.0.1/ldap-worker-ad < ../workers/ad-worker.yml \
		&& echo Worker configs published
	cd ldap && $(DOCKER_COMPOSE) up -d
	cd workers && $(DOCKER_COMPOSE) up -d
	cd cluster && $(DOCKER_COMPOSE) up -d

stop:
	cd cluster && $(DOCKER_COMPOSE) down
	cd workers && $(DOCKER_COMPOSE) down
	cd ldap && $(DOCKER_COMPOSE) down
	cd tools && $(DOCKER_COMPOSE) down
	docker container prune -f
	docker network prune -f
