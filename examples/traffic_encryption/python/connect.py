import tarantool

con = tarantool.Connection(
    'tarantool-router-msk',
    3301,
    user="admin",
    password="secret-cluster-cookie",
    transport='ssl',
    ssl_key_file='certs/tarantool/client-key.pem',
    ssl_cert_file='certs/tarantool/client.pem',
    ssl_ca_file='certs/ca/root-ca.pem',
    ssl_password='54321',
    connection_timeout=0.5,
    socket_timeout=0.5,
)

print(con.eval("return box.info.version"))

con.close()
