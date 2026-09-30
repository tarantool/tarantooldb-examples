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
.PHONY: start stop backup-full backup-incremental restore
start:
	docker network create tarantooldb_network
	cd tools \
		&& $(DOCKER_COMPOSE) up -d --build \
		&& $(DOCKER_COMPOSE) exec -T publisher bash -c "\
			tools/client/wait_etcd_ready.sh 15 http://etcd1:2379 \
			&& tools/client/wait_etcd_ready.sh 15 http://etcd2:2379 \
			&& tools/client/wait_etcd_ready.sh 15 http://etcd3:2379 \
			&& tt cluster publish http://etcd1:2379/tdb config.yml --force \
			&& tools/client/wait_config_ready.sh 25 http://etcd1:2379/tdb \
			&& echo Load config done"
	cd cluster && $(DOCKER_COMPOSE) up -d --build

stop:
	cd cluster && $(DOCKER_COMPOSE) down -v
	cd tools && $(DOCKER_COMPOSE) down
	docker container prune -f
	docker network prune -f

backup-full:
	./scripts/backup.sh full

backup-incremental:
	./scripts/backup.sh incremental

restore:
	./scripts/restore.sh "$(TARGET_TIME)"

