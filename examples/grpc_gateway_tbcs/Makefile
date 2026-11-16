SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DEFAULT_GOAL := start

ifneq ($(shell command -v docker-compose 2>/dev/null),)
    DOCKER_COMPOSE = docker-compose
endif
ifneq ($(shell docker compose version 2>/dev/null),)
    DOCKER_COMPOSE = docker compose
endif
ifndef DOCKER_COMPOSE
    $(error Не найден docker-compose или docker compose)
endif

COMPOSE := $(DOCKER_COMPOSE) -p tdb-grpc-tbcs-example -f cluster/docker-compose.yml

PUBLISH_WORKERS = $(COMPOSE) exec -T tcm bash -ec 'source tools/client/get_config_master.sh client:secret@tarantool-config-storage-1:3301; test -n "$$CONFIG_MASTER"; for name in grpc-gateway-1 grpc-gateway-2; do tt cluster worker publish "http://client:secret@$$CONFIG_MASTER/tdb-workers/grpc-tbcs-example/$$name/$$name" "$$name.yml" --force; done'

.PHONY: start publish-workers stop ps logs logs-gateway

start:
	$(COMPOSE) up -d tarantool-config-storage-1 tarantool-config-storage-2 tarantool-config-storage-3
	for n in 1 2 3; do
	    $(COMPOSE) exec -T tarantool-config-storage-$$n tools/client/wait_instance_ready.sh 60 ./var/run/config-storage-$$n/tarantool.control
	done
	$(COMPOSE) up -d tcm
	$(COMPOSE) exec -T tcm bash -ec 'source tools/client/get_config_master.sh client:secret@tarantool-config-storage-1:3301; test -n "$$CONFIG_MASTER"; tt cluster publish "http://client:secret@$$CONFIG_MASTER/tdb" config.yml --force; tools/client/wait_config_ready.sh 30 http://client:secret@tarantool-config-storage-1:3301/tdb'
	$(PUBLISH_WORKERS)
	$(COMPOSE) up -d router-1 storage-1-a storage-1-b storage-2-a storage-2-b
	$(COMPOSE) run --rm init_host
	$(COMPOSE) up -d grpc-gateway-1 grpc-gateway-2
	@echo 'Стенд запущен: gRPC localhost:9091 и localhost:9092, TCM http://localhost:8081'

publish-workers:
	$(PUBLISH_WORKERS)

ps:
	$(COMPOSE) --profile gateway ps

logs:
	$(COMPOSE) --profile gateway logs --tail=100

logs-gateway:
	$(COMPOSE) logs -f --tail=100 grpc-gateway-1 grpc-gateway-2

stop:
	$(COMPOSE) --profile init --profile gateway down --remove-orphans
