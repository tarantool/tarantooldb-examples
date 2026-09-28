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

TDB_IMAGE ?= tarantooldb:3x-latest
TCM_HOST_PORT ?= 8081
ROUTER_HOST_PORT ?= 3301
GATEWAY_HOST_PORT ?= 9091
GATEWAY_INSTR_HOST_PORT ?= 9081
export TDB_IMAGE TCM_HOST_PORT ROUTER_HOST_PORT GATEWAY_HOST_PORT GATEWAY_INSTR_HOST_PORT

NETWORK := tdb_grpc_example_network
TOOLS := $(DOCKER_COMPOSE) -p tdb-grpc-tools -f tools/docker-compose.yml
CLUSTER := $(DOCKER_COMPOSE) -p tdb-grpc-cluster -f cluster/docker-compose.yml

.PHONY: start stop publish-config publish-worker-config show-worker-config bootstrap ps logs logs-worker

start:
	docker network inspect $(NETWORK) >/dev/null 2>&1 || docker network create $(NETWORK)
	$(TOOLS) up -d
	$(MAKE) publish-config
	$(MAKE) publish-worker-config
	$(CLUSTER) up -d router-1 storage-1-a storage-1-b storage-2-a storage-2-b
	$(MAKE) bootstrap
	$(CLUSTER) up -d grpc-gateway
	@echo "Стенд запущен: gRPC localhost:$(GATEWAY_HOST_PORT), TCM http://localhost:$(TCM_HOST_PORT)"

publish-config:
	$(TOOLS) exec -T tcm sh -ec 'tools/client/wait_etcd_ready.sh 30 http://etcd:2379 && tt cluster publish http://etcd:2379/tdb config.yml --force && tools/client/wait_config_ready.sh 30 http://etcd:2379/tdb'

publish-worker-config:
	$(TOOLS) exec -T -e ETCDCTL_API=3 etcd etcdctl --endpoints=http://etcd:2379 put \
		/tdb-workers/grpc-example/instances/grpc-gateway/grpc-gateway < workers/grpc-gateway.yml

show-worker-config:
	$(TOOLS) exec -T -e ETCDCTL_API=3 etcd etcdctl --endpoints=http://etcd:2379 get \
		/tdb-workers/grpc-example/instances/grpc-gateway/grpc-gateway --print-value-only

bootstrap:
	$(CLUSTER) run --rm init_host

ps:
	$(TOOLS) ps
	$(CLUSTER) --profile worker ps

logs:
	$(CLUSTER) logs --tail=100
	$(TOOLS) logs --tail=100

logs-worker:
	$(CLUSTER) logs -f --tail=100 grpc-gateway

stop:
	$(CLUSTER) --profile init --profile worker down --remove-orphans
	$(TOOLS) down --remove-orphans
	-docker network rm $(NETWORK)
