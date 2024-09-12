FROM centos:7

WORKDIR /opt/tarantool

COPY ./tcf-destination /usr/local/bin/tcf-destination
COPY ./tcf-gateway /usr/local/bin/tcf-gateway
COPY ./config_1to2.yml /opt/tarantool/config_1to2.yml
COPY ./config_2to1.yml /opt/tarantool/config_2to1.yml
