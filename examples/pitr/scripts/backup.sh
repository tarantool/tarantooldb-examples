#!/usr/bin/env bash
#
# Оркестратор резервного копирования: вызывает команды tt на узлах и менеджере.
#
# Использование:
#   ./scripts/backup.sh full
#   ./scripts/backup.sh incremental

set -euo pipefail

MODE="${1:?Укажите режим: full или incremental}"

cd "$(dirname "$0")/.."
COMPOSE="docker compose -f cluster/docker-compose.yml"

# Учётные данные из cluster/config.yml.
CLUSTER_CFG="http://etcd1:2379/tdb"
TT_USER="admin"
TT_PASS="secret-cluster-cookie"

echo "=== 1. Идентификатор резервной копии (tt backup-id) ==="
BACKUP_ID=$($COMPOSE exec -T manager tt backup-id)
echo "backup id: $BACKUP_ID"

echo "=== 2. План резервного копирования (tt backup plan) ==="
$COMPOSE exec -T manager sh -c "tt backup plan --target=$MODE \
  --backup-storage file:///backup/storage \
  -c $CLUSTER_CFG -u $TT_USER -p $TT_PASS \
  --format json > /backup/plan.json"

# План нужен на хосте, чтобы раздать команды по узлам.
$COMPOSE exec -T manager cat /backup/plan.json > /tmp/pitr-plan.json

echo "=== 3. Снятие резервной копии с узлов (tt backup start) ==="
for MASTER in $(jq -r '.replicasets[].master_instance_name' /tmp/pitr-plan.json); do
  # Имя экземпляра (storage-1-msk) -> имя сервиса (tarantool-storage-1-msk).
  CONTAINER="tarantool-$MASTER"
  URI="$TT_USER:$TT_PASS@$CONTAINER:3301"
  ARGS=(--backup-id "$BACKUP_ID" --dir /backup/archives)

  FROM_VCLOCK=$(jq -c --arg n "$MASTER" \
    '.replicasets[] | select(.master_instance_name==$n) | .from_vclock' \
    /tmp/pitr-plan.json)
  if [ "$FROM_VCLOCK" != "null" ]; then
    ARGS+=(--from-vclock "$FROM_VCLOCK")
  fi

  echo "  -> $MASTER"
  $COMPOSE exec -T "$CONTAINER" tt backup start "$URI" "${ARGS[@]}"
done

echo "=== 4. Загрузка в хранилище (tt backup upload) ==="
ARCHIVES=""
FRAGMENTS=""
for UUID in $(jq -r '.replicasets | keys[]' /tmp/pitr-plan.json); do
  ARCHIVES="$ARCHIVES,/backup/archives/$BACKUP_ID-$UUID.tar.zst"
  FRAGMENTS="$FRAGMENTS,/backup/archives/$BACKUP_ID-$UUID.json"
done
ARCHIVES="${ARCHIVES#,}"
FRAGMENTS="${FRAGMENTS#,}"

$COMPOSE exec -T manager tt backup upload \
  --archives "$ARCHIVES" \
  --fragments "$FRAGMENTS" \
  --plan /backup/plan.json \
  --backup-storage file:///backup/storage \
  --backup-id "$BACKUP_ID"

echo "=== 5. Финализация (tt backup finalize) ==="
for MASTER in $(jq -r '.replicasets[].master_instance_name' /tmp/pitr-plan.json); do
  CONTAINER="tarantool-$MASTER"
  URI="$TT_USER:$TT_PASS@$CONTAINER:3301"
  echo "  -> $MASTER"
  $COMPOSE exec -T "$CONTAINER" tt backup finalize "$URI" \
    --backup-id "$BACKUP_ID" --dir /backup/archives
done

echo "Готово: резервная копия $BACKUP_ID ($MODE) записана в хранилище."
