SHELL := /bin/bash

.SILENT: start
start:
	# Create network
	docker network create tarantooldb_network
	# Run tools
	cd tools && docker compose up -d
	# Check that the tools are ready
	cd tools && (timeout 15 sh -c 'until docker compose logs etcd1 | grep -q "ready to serve client requests"; do sleep 0.1; done' || (echo "Error: etcd1 did not become ready within 15 seconds" && exit 1)) \
	&& (timeout 15 sh -c 'until docker compose logs etcd2 | grep -q "ready to serve client requests"; do sleep 0.1; done' || (echo "Error: etcd2 did not become ready within 15 seconds" && exit 1)) \
	&& (timeout 15 sh -c 'until docker compose logs etcd3 | grep -q "ready to serve client requests"; do sleep 0.1; done' || (echo "Error: etcd3 did not become ready within 15 seconds" && exit 1)) \
	&& (timeout 15 sh -c 'until docker compose logs prometheus | grep "Server is ready to receive web requests."; do sleep 0.1; done' || (echo "Error: prometheus did not become ready within 15 seconds" && exit 1))
	# Load config
	docker compose -f load-config.yml up -d
	# Checking that the configuration has loaded
	timeout 15 sh -c 'until docker compose -f load-config.yml logs load_config | grep "credentials:"; do sleep 1; done' || (echo "Error: after 15 seconds the configuration was still not loaded" && exit 1)
	# Run cluster
	cd cluster && docker compose up -d

stop:
	cd cluster && docker compose down
	cd tools && docker compose down
	docker container prune -f
	docker network prune -f
