FROM centos:7

WORKDIR /opt/tarantool


COPY ./bin/tcf-destination /usr/local/bin/tcf-destination
COPY ./bin/tcf-gateway /usr/local/bin/tcf-gateway
COPY ./config_repl_AB.yaml /opt/tarantool/config_repl_AB.yaml
COPY ./config_repl_BA.yaml /opt/tarantool/config_repl_BA.yaml
