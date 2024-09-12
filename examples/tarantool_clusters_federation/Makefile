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
			&& tt cluster publish http://etcd1:2379/tdb1 config1.yml --force \
			&& tools/client/wait_config_ready.sh 25 http://etcd1:2379/tdb1 \
			&& tt cluster publish http://etcd1:2379/tdb2 config2.yml --force \
			&& tools/client/wait_config_ready.sh 25 http://etcd1:2379/tdb2 \
			&& echo Load config done"
	cd cluster1 && docker compose up -d --build
	cd cluster2 && docker compose up -d --build

stop:
	cd tcf && docker compose down
	cd cluster2 && docker compose down
	cd cluster1 && docker compose down
	cd tools && docker compose down
	docker container prune -f
	docker network prune -f
