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

COMPOSE := $(DOCKER_COMPOSE) -p tdb-grpc-tls -f cluster/docker-compose.yml

.PHONY: prepare start stop ps logs

prepare:
	umask 077
	mkdir -p _local/{ca,gateway,storage,client}
	if [[ ! -f _local/ca/ca.key ]]; then
	    openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj /CN=grpc-tls-example-ca \
	        -addext basicConstraints=critical,CA:TRUE -addext keyUsage=critical,keyCertSign,cRLSign \
	        -keyout _local/ca/ca.key -out _local/ca/ca.crt
	fi
	for name in gateway storage client; do
	    if [[ ! -f "_local/$$name/$$name.crt" ]]; then
	        openssl req -new -newkey rsa:2048 -nodes -subj "/CN=$$name" \
	            -keyout "_local/$$name/$$name.key" -out "_local/ca/$$name.csr"
	        case $$name in
	            gateway) usage=serverAuth; san='DNS:localhost,IP:127.0.0.1,DNS:grpc-gateway-1' ;;
	            storage) usage=serverAuth,clientAuth; san='DNS:router-1,DNS:storage-1-a,DNS:storage-2-a' ;;
	            client) usage=clientAuth; san='DNS:grpc-client' ;;
	        esac
	        printf 'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=%s\nsubjectAltName=%s\n' "$$usage" "$$san" > "_local/ca/$$name.ext"
	        openssl x509 -req -days 30 -in "_local/ca/$$name.csr" \
	            -CA _local/ca/ca.crt -CAkey _local/ca/ca.key -CAcreateserial \
	            -extfile "_local/ca/$$name.ext" -out "_local/$$name/$$name.crt"
	    fi
	    cp _local/ca/ca.crt "_local/$$name/ca.crt"
	    openssl verify -CAfile _local/ca/ca.crt "_local/$$name/$$name.crt"
	done

start: prepare
	$(COMPOSE) up -d etcd
	$(COMPOSE) run --rm init_host sh -ec 'tools/client/wait_etcd_ready.sh 30 http://etcd:2379 && tt cluster publish http://etcd:2379/tdb config.yml --force && tools/client/wait_config_ready.sh 30 http://etcd:2379/tdb'
	$(COMPOSE) exec -T etcd etcdctl put \
	    /tdb-workers/grpc-tls-example/instances/grpc-gateway-1/grpc-gateway-1 < cluster/grpc-gateway-1.yml
	$(COMPOSE) up -d router-1 storage-1-a storage-2-a
	$(COMPOSE) run --rm init_host
	$(COMPOSE) up -d --wait --wait-timeout 90 grpc-gateway-1
	@echo 'Стенд запущен: gRPC TLS localhost:9443, /ready http://localhost:9181/ready'

ps:
	$(COMPOSE) --profile gateway ps

logs:
	$(COMPOSE) --profile gateway logs --tail=100

stop:
	$(COMPOSE) --profile init --profile gateway down --volumes --remove-orphans
