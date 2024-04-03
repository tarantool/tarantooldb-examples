
failover='{"query":"mutation {
    cluster { failover_params(
        mode: \"stateful\"
        failover_timeout: 20
        state_provider: \"etcd2\"
        etcd2_params: {
            endpoints: [\"etcd1:2379\", \"etcd2:2379\", \"etcd3:2379\"]
            prefix: \"cluster_A\"
        }) {
            mode
        }
    }
}"}'

curl -i -H 'Content-Type: application/json' -X POST -d "${failover}" http://${TARANTOOLDB_TARGET_URI}/admin/api

echo "Setup Failover Done!"