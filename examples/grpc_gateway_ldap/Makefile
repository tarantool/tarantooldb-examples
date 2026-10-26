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

COMPOSE := $(DOCKER_COMPOSE) -p tdb-grpc-ldap -f cluster/docker-compose.yml

.PHONY: start prepare restart-workers stop ps logs logs-gateway

start: prepare
	$(COMPOSE) up -d etcd tcm
	$(COMPOSE) up -d --wait --wait-timeout 120 ldap
	$(COMPOSE) exec -T tcm sh -ec 'tools/client/wait_etcd_ready.sh 30 http://etcd:2379 && tt cluster publish http://etcd:2379/tdb config.yml --force && tools/client/wait_config_ready.sh 30 http://etcd:2379/tdb'
	$(COMPOSE) exec -T -e ETCDCTL_API=3 etcd etcdctl --endpoints=http://etcd:2379 put \
		/tdb-workers/grpc-ldap-example/instances/grpc-gateway-1/grpc-gateway-1 < cluster/grpc-gateway-1.yml
	$(COMPOSE) exec -T -e ETCDCTL_API=3 etcd etcdctl --endpoints=http://etcd:2379 put \
		/tdb-workers/grpc-ldap-example/instances/grpc-gateway-2/grpc-gateway-2 < cluster/grpc-gateway-2.yml
	$(COMPOSE) exec -T -e ETCDCTL_API=3 etcd etcdctl --endpoints=http://etcd:2379 put \
		/tdb-workers/grpc-ldap-example/instances/ldap-worker/ldap-worker < cluster/ldap-worker.yml
	$(COMPOSE) up -d router-1 storage-1-a storage-1-b storage-2-a storage-2-b
	$(COMPOSE) run --rm init_host
	$(COMPOSE) up -d --wait --wait-timeout 90 ldap-worker grpc-gateway-1 grpc-gateway-2
	@echo "Стенд запущен: gRPC localhost:9091 и localhost:9092, TCM http://localhost:8081"

ps:
	$(COMPOSE) --profile gateway ps

logs:
	$(COMPOSE) --profile gateway logs --tail=100

logs-gateway:
	$(COMPOSE) logs -f --tail=100 grpc-gateway-1 grpc-gateway-2

stop:
	$(COMPOSE) --profile init --profile gateway down --volumes --remove-orphans

prepare:
	state="$$PWD/_local"
	umask 077
	mkdir -p "$$state"/{ca,gateway,worker,ldap}

	if [[ ! -f "$$state/ca/ca.key" ]]; then
	    openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
	        -subj /CN=ldap-demo-ca -keyout "$$state/ca/ca.key" -out "$$state/ca/ca.crt"
	fi
	for name in gateway worker ldap; do
	    target=$$name
	    [[ $$name != worker ]] || target=ldap-worker
	    if [[ ! -f "$$state/$$name/$$name.crt" ]]; then
	        openssl req -new -newkey rsa:2048 -nodes -subj "/CN=$$target" \
	            -keyout "$$state/$$name/$$name.key" -out "$$state/ca/$$name.csr"
	        printf 'subjectAltName=DNS:%s,DNS:localhost,IP:127.0.0.1\nextendedKeyUsage=serverAuth\n' "$$target" > "$$state/ca/$$name.ext"
	        openssl x509 -req -days 30 -in "$$state/ca/$$name.csr" \
	            -CA "$$state/ca/ca.crt" -CAkey "$$state/ca/ca.key" -CAcreateserial \
	            -extfile "$$state/ca/$$name.ext" -out "$$state/$$name/$$name.crt"
	    fi
	    cp "$$state/ca/ca.crt" "$$state/$$name/ca.crt"
	    openssl verify -CAfile "$$state/ca/ca.crt" "$$state/$$name/$$name.crt"
	done
	[[ -s "$$state/gateway/session-key" ]] || openssl rand -hex 32 > "$$state/gateway/session-key"
	[[ -s "$$state/gateway/worker-token" ]] || openssl rand -hex 32 > "$$state/gateway/worker-token"
	cp "$$state/gateway/worker-token" "$$state/worker/worker-token"
	# A standard DH group avoids OpenLDAP generating a fresh safe prime at startup.
	openssl genpkey -genparam -algorithm DH -pkeyopt group:ffdhe2048 -out "$$state/ldap/dhparam.pem"
	# OpenLDAP copies these files into its container and runs slapd as its own user.
	chmod 755 "$$state/ldap"
	chmod 644 "$$state/ldap/ca.crt" "$$state/ldap/ldap.crt"

	grpcurl -import-path proto \
	    -proto tdb/auth/v1/auth.proto \
	    -proto tdb/crud/v1/service.proto \
	    -protoset-out "$$state/api.protoset" list >/dev/null
	test -s "$$state/api.protoset"
	printf 'Prepared %s\n' "$$state"

restart-workers:
	$(COMPOSE) exec -T etcd etcdctl put /tdb-workers/grpc-ldap-example/instances/ldap-worker/ldap-worker < cluster/ldap-worker.yml
	for name in grpc-gateway-1 grpc-gateway-2; do
	    $(COMPOSE) exec -T etcd etcdctl put "/tdb-workers/grpc-ldap-example/instances/$$name/$$name" < "cluster/$$name.yml"
	done
	$(COMPOSE) up -d --no-deps --force-recreate --wait --wait-timeout 90 ldap-worker grpc-gateway-1 grpc-gateway-2
