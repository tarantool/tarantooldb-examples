FROM tarantooldb:latest as tt

FROM alpine:3.18.4

RUN apk add --no-cache curl

COPY ./bootstrap /bootstrap/
COPY --from=tt /app/tarantooldb/client/utils/bootstrap.sh /bootstrap/bootstrap.sh
COPY --from=tt /app/tarantooldb/client/utils/health_check.sh /bootstrap/health_check.sh
COPY --from=tt /app/tarantooldb/client/utils/migrate.sh /bootstrap/migrate.sh

RUN chmod +x /bootstrap/bootstrap.sh
RUN chmod +x /bootstrap/health_check.sh
RUN chmod +x /bootstrap/migrate.sh
