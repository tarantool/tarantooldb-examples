SHELL := /bin/bash

.SILENT: start
start:
	docker network create tarantooldb_network
	cd config_storage \
		&& docker compose up -d \
		&& docker compose exec -it tarantool-config-storage-1 bash tools/client/wait_instance_ready.sh 15 ./var/run/config-storage-1/tarantool.control \
		&& docker compose exec -it tarantool-config-storage-2 bash tools/client/wait_instance_ready.sh 15 ./var/run/config-storage-2/tarantool.control \
		&& docker compose exec -it tarantool-config-storage-3 bash tools/client/wait_instance_ready.sh 15 ./var/run/config-storage-3/tarantool.control
	cd main_cluster \
		&& docker compose -f load-config.yml up -d
	cd config_storage \
		&& docker compose exec -it tarantool-config-storage-1 bash tools/client/wait_config_ready.sh 25 http://client:secret@tarantool-config-storage-1:3301/tdb
	cd main_cluster \
		&& docker compose up -d
	cd tools \
		&& docker compose up -d

stop:
	cd tools && docker compose down
	cd main_cluster && docker compose down
	cd config_storage && docker compose down
	docker container prune -f
	docker network prune -f
