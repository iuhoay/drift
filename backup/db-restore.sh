#!/usr/bin/env bash
# Restore a drift backup produced by db-backup. Runs inside the accessory, e.g.:
#   kamal accessory exec db_backup --reuse "db-restore daily/2026-06-15.dump"
#
# Defaults to a SCRATCH database (drift_restore_check) so drills never touch
# production. For a real recovery set TARGET_DB=drift_production AND stop the app
# first — Postgres cannot drop a database that still has live connections.
#
# Non-interactive callers (like `kamal accessory exec`) must pass FORCE=1, which
# skips the typed confirmation.
set -euo pipefail

PG_HOST="${PG_HOST:-drift-db}"
PG_USER="${PG_USER:-root}"
export PGPASSWORD="${PG_PASSWORD:-}"
TARGET_DB="${TARGET_DB:-drift_restore_check}"
S3_BUCKET="${S3_BUCKET:?set S3_BUCKET}"
S3_PREFIX="${S3_PREFIX:-drift}"
S3_ENDPOINT="${S3_ENDPOINT:?set S3_ENDPOINT}"
FORCE="${FORCE:-}"

src="${1:?usage: db-restore <remote-relative-path>  e.g. daily/2026-06-15.dump}"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
dump="${work}/restore.dump"

echo "[db-restore] fetching ${src}…"
aws --endpoint-url "$S3_ENDPOINT" s3 cp "s3://${S3_BUCKET}/${S3_PREFIX}/${src}" "$dump"

echo "[db-restore] target=${TARGET_DB} on ${PG_HOST} — this DROPs and recreates it."
if [ "$FORCE" != "1" ]; then
  read -r -p "Type the target DB name to confirm: " confirm
  [ "$confirm" = "$TARGET_DB" ] || { echo "[db-restore] name mismatch — aborted."; exit 1; }
fi

echo "[db-restore] recreating ${TARGET_DB}…"
psql -h "$PG_HOST" -U "$PG_USER" -d postgres -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS ${TARGET_DB};" \
  -c "CREATE DATABASE ${TARGET_DB};"

echo "[db-restore] restoring…"
pg_restore -h "$PG_HOST" -U "$PG_USER" -d "$TARGET_DB" --no-owner --no-privileges "$dump"

echo "[db-restore] restored into ${TARGET_DB}. Sanity check:"
psql -h "$PG_HOST" -U "$PG_USER" -d "$TARGET_DB" -c \
  "SELECT (SELECT count(*) FROM users) AS users, (SELECT count(*) FROM subscriptions) AS subscriptions;" \
  2>/dev/null || echo "  (table counts unavailable — inspect manually)"
