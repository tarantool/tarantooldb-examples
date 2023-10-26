#!/bin/bash

curl 'http://localhost:8081/admin/api' \
  --data-binary $'{"operationName":"editTopology","variables":{"replicasets":[{"alias":"tarantool-db","roles":["crud-storage","vshard-storage","expirationd","app.roles.storage","space-explorer","vshard-router"],"weight":null,"all_rw":false,"vshard_group":"default","join_servers":[{"uri":"172.17.0.2:3301"}]}]},"query":"mutation editTopology($replicasets: [EditReplicasetInput!], $servers: [EditServerInput!]) {\n  cluster {\n    edit_topology(replicasets: $replicasets, servers: $servers) {\n      servers {\n        uuid\n      }\n    }\n  }\n}\n"}'

curl 'http://localhost:8081/admin/api' \
  --data-binary '{"operationName":"bootstrap","variables":{},"query":"mutation bootstrap {\n  bootstrapVshardResponse: bootstrap_vshard\n}\n"}'

echo "---" > ./to_load.yml
cat ./migrations/config.yml >> ./to_load.yml

for filename in $(find migrations -name *.lua)
do
  echo $filename ": |-" >> ./to_load.yml
  cat $filename | sed 's/^/  /' >> ./to_load.yml
done

echo "..." >> ./to_load.yml

curl 'http://localhost:8081/admin/config' --upload-file to_load.yml
rm -rf ./to_load.yml
curl -XPOST 'http://localhost:8081/migrations/up'
