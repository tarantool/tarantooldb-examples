SHELL := /bin/bash
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

COMPOSE := $(DOCKER_COMPOSE) -p tdb-grpc-audit -f cluster/docker-compose.yml

.PHONY: start stop ps logs logs-gateway

start:
	$(COMPOSE) up -d etcd tcm
	$(COMPOSE) exec -T tcm sh -ec 'tools/client/wait_etcd_ready.sh 30 http://etcd:2379 && tt cluster publish http://etcd:2379/tdb config.yml --force && tools/client/wait_config_ready.sh 30 http://etcd:2379/tdb'
	$(COMPOSE) exec -T -e ETCDCTL_API=3 etcd etcdctl --endpoints=http://etcd:2379 put \
		/tdb-workers/grpc-audit-example/instances/grpc-gateway-1/grpc-gateway-1 < cluster/grpc-gateway-1.yml
	$(COMPOSE) exec -T -e ETCDCTL_API=3 etcd etcdctl --endpoints=http://etcd:2379 put \
		/tdb-workers/grpc-audit-example/instances/grpc-gateway-2/grpc-gateway-2 < cluster/grpc-gateway-2.yml
	$(COMPOSE) up -d router-1 storage-1-a storage-1-b storage-2-a storage-2-b
	$(COMPOSE) run --rm init_host
	$(COMPOSE) up -d grpc-gateway-1 grpc-gateway-2
	@echo "Стенд запущен: gRPC localhost:9091 и localhost:9092, TCM http://localhost:8081"

ps:
	$(COMPOSE) --profile gateway ps

logs:
	$(COMPOSE) --profile gateway logs --tail=100

logs-gateway:
	$(COMPOSE) logs -f --tail=100 grpc-gateway-1 grpc-gateway-2

stop:
	$(COMPOSE) --profile init --profile gateway down --remove-orphans
