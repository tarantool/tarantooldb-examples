#!/usr/bin/env bash
#
# Оркестратор восстановления на момент времени.
#
# Использование:
#   ./scripts/restore.sh <target-time>
#
# <target-time> задаёт время точки восстановления в целых секундах
# или в формате RFC 3339, например 1790634819 или 2026-09-28T22:33:39Z.

set -euo pipefail

TARGET_TIME="${1:?Укажите target-time (время точки восстановления)}"

cd "$(dirname "$0")/.."
COMPOSE="docker compose -f cluster/docker-compose.yml"

CLUSTER_CFG="http://etcd1:2379/tdb"
# Только хранилища с данными: роутер поднимается с нуля.
REPLICASETS="storage-1,storage-2"
STORAGE_NODES="tarantool-storage-1-msk tarantool-storage-1-spb tarantool-storage-1-brn \
  tarantool-storage-2-msk tarantool-storage-2-spb tarantool-storage-2-brn"

echo "=== 1. План восстановления (tt restore plan) ==="
$COMPOSE exec -T manager sh -c "rm -rf /backup/restore && mkdir -p /backup/restore && \
  tt restore plan --target-time '$TARGET_TIME' \
    --backup-storage file:///backup/storage \
    -c $CLUSTER_CFG \
    --replicasets $REPLICASETS \
    -d /backup/restore \
    --format json > /backup/restore/plan.json"

$COMPOSE exec -T manager cat /backup/restore/plan.json > /tmp/pitr-restore-plan.json

echo "=== 2. Остановка хранилищ ==="
$COMPOSE stop $STORAGE_NODES

echo "=== 3. Восстановление данных (tt restore apply) ==="
for RS_UUID in $(jq -r '.restore_targets | keys[]' /tmp/pitr-restore-plan.json); do
  ARCHIVES=$(jq -r --arg u "$RS_UUID" \
    '.download_plan[$u] | map(.artifact) | join(",")' /tmp/pitr-restore-plan.json)
  TARGET_POINT=$(jq -c --arg u "$RS_UUID" \
    '.recovery_point.trim_to_by_replicaset[$u]' /tmp/pitr-restore-plan.json)

  while IFS=$'\t' read -r INSTANCE PATCH_UUID; do
    echo "  -> $INSTANCE"
    $COMPOSE exec -T manager tt restore apply \
      --archives "$ARCHIVES" \
      --work-dir "/data/$INSTANCE" \
      --target-point "$TARGET_POINT" \
      --patch-uuid "$PATCH_UUID" < /dev/null
  done < <(jq -r --arg u "$RS_UUID" \
    '.restore_targets[$u].instances[] | [.instance_name, .patch_uuid] | @tsv' \
    /tmp/pitr-restore-plan.json)
done

echo "=== 4. Запуск хранилищ ==="
$COMPOSE start $STORAGE_NODES

echo "Готово: кластер восстановлен на $TARGET_TIME."
