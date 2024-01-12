#!/bin/bash

docker run -d \
  --name tarantool-db-1 \
  --hostname tarantool-db-1 \
  -e TARANTOOL_INSTANCE_NAME=tarantool-db-1 \
  -e TARANTOOL_ADVERTISE_URI=3301 \
  -e TARANTOOL_CLUSTER_COOKIE=secret-cluster-cookie \
  -e TARANTOOL_HTTP_PORT=8081 \
  -p 127.0.0.1:8081:8081 \
  -p 127.0.0.1:3301:3301 \
  tarantooldb:latest
