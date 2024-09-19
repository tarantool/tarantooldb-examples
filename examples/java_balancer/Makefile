SHELL := /bin/bash

.SILENT: start
start:
	docker network create tarantooldb_network
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

stop:
	cd cluster && docker compose down
	cd tools && docker compose down
	docker container prune -f
	docker network prune -f
