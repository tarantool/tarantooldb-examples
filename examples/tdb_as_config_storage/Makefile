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
	docker network create tarantooldb_network
	cd config_storage \
		&& $(DOCKER_COMPOSE) up -d \
		&& $(DOCKER_COMPOSE) exec -it tarantool-config-storage-1 bash tools/client/wait_instance_ready.sh 15 ./var/run/config-storage-1/tarantool.control \
		&& $(DOCKER_COMPOSE) exec -it tarantool-config-storage-2 bash tools/client/wait_instance_ready.sh 15 ./var/run/config-storage-2/tarantool.control \
		&& $(DOCKER_COMPOSE) exec -it tarantool-config-storage-3 bash tools/client/wait_instance_ready.sh 15 ./var/run/config-storage-3/tarantool.control
	cd tools \
		&& $(DOCKER_COMPOSE) up -d \
		&& $(DOCKER_COMPOSE) exec -it tcm-1 bash -c '\
			source tools/client/get_config_master.sh client:secret@tarantool-config-storage-1:3301 \
			&& tt cluster publish http://client:secret@$$CONFIG_MASTER/tdb config.yml --force \
			&& tools/client/wait_config_ready.sh 25 http://client:secret@tarantool-config-storage-1:3301/tdb \
			&& echo Load config done'
	cd main_cluster \
		&& $(DOCKER_COMPOSE) up -d

stop:
	cd main_cluster && $(DOCKER_COMPOSE) down
	cd tools && $(DOCKER_COMPOSE) down
	cd config_storage && $(DOCKER_COMPOSE) down
	docker container prune -f
	docker network prune -f
