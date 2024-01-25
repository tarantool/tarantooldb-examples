local net_box = require('net.box')

local conn = net_box.connect({
    uri = 'admin:secret-cluster-cookie@localhost:3301',
    params = {
        transport = 'ssl',
        ssl_cert_file='./bootstrap/client-cert.pem',
        ssl_key_file='./bootstrap/client-key.pem',
        ssl_ca_file='./bootstrap/ca-cert.pem'
    }
})

local res = conn:eval("return 1+1")

print(res)
