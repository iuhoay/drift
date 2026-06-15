#!/usr/bin/env bash
# One backup run: dump drift_production, verify it, upload to S3-compatible
# storage (Cloudflare R2 / Backblaze B2) with the AWS CLI, promote daily/weekly
# copies, and prune each tier by age.
#
# Runs INSIDE the backup accessory (see backup/Dockerfile). It reaches Postgres
# over the Kamal network (PG_HOST=drift-db) — no Docker socket needed.
#
# Only `drift_production` is backed up; the *_cache/_queue/_cable/_rails_pulse
# databases regenerate, and roles come from docker/postgres-init.sql, so this
# dump plus the repo fully reconstitute production. See docs/backups.md.
set -euo pipefail

PG_HOST="${PG_HOST:-drift-db}"
PG_USER="${PG_USER:-root}"
PG_DATABASE="${PG_DATABASE:-drift_production}"
export PGPASSWORD="${PG_PASSWORD:-}"            # empty is fine under trust auth

S3_BUCKET="${S3_BUCKET:?set S3_BUCKET}"
S3_PREFIX="${S3_PREFIX:-drift}"
S3_ENDPOINT="${S3_ENDPOINT:?set S3_ENDPOINT (R2/B2 endpoint URL)}"
# Credentials + region come from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY /
# AWS_DEFAULT_REGION in the environment (read natively by the AWS CLI).

KEEP_RECENT_DAYS="${KEEP_RECENT_DAYS:-3}"
KEEP_DAILY_DAYS="${KEEP_DAILY_DAYS:-30}"
KEEP_WEEKLY_DAYS="${KEEP_WEEKLY_DAYS:-180}"
HEALTHCHECK_URL="${HEALTHCHECK_URL:-}"

aws_s3() { aws --endpoint-url "$S3_ENDPOINT" "$@"; }
s3uri()  { echo "s3://${S3_BUCKET}/${S3_PREFIX}/$1"; }
log()    { printf '[db-backup] %s %s\n' "$(date -u +%H:%M:%S)" "$*"; }
ping()   { [ -n "$HEALTHCHECK_URL" ] && curl -fsS -m 10 "$1" >/dev/null 2>&1 || true; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
trap 'log "FAILED (line $LINENO)"; ping "${HEALTHCHECK_URL}/fail"' ERR

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
day="$(date -u +%Y-%m-%d)"
week="$(date -u +%G-W%V)"
file="${PG_DATABASE}_${stamp}.dump"
path="${WORKDIR}/${file}"

# ---- Dump (custom format: compressed + selectively restorable) ---------------
log "dumping ${PG_DATABASE} from ${PG_HOST}…"
pg_dump -h "$PG_HOST" -U "$PG_USER" -Fc --no-owner --no-privileges "$PG_DATABASE" > "$path"

# ---- Verify before upload ----------------------------------------------------
# pg_restore --list parses the archive TOC; a truncated/corrupt dump fails here
# and never reaches the bucket.
log "verifying archive…"
pg_restore --list "$path" > /dev/null
log "archive ok ($(du -h "$path" | cut -f1))"

# ---- Upload + promote --------------------------------------------------------
log "uploading recent/${file}…"
aws_s3 s3 cp "$path" "$(s3uri "recent/${file}")"

# First run of each day / ISO week is promoted into longer-lived tiers. Keyed by
# period so exactly one survives per day and per week, idempotent across runs.
if ! aws_s3 s3 ls "$(s3uri "daily/${day}.dump")" >/dev/null 2>&1; then
  log "promoting daily/${day}.dump"
  aws_s3 s3 cp "$path" "$(s3uri "daily/${day}.dump")"
fi
if ! aws_s3 s3 ls "$(s3uri "weekly/${week}.dump")" >/dev/null 2>&1; then
  log "promoting weekly/${week}.dump"
  aws_s3 s3 cp "$path" "$(s3uri "weekly/${week}.dump")"
fi

# ---- Prune by age (best-effort; never fails an otherwise-good run) -----------
prune() {  # <subdir/> <max-age-days>
  local sub="$1" days="$2" cutoff keys key
  cutoff="$(date -u -d "-${days} days" +%Y-%m-%dT%H:%M:%S)"
  keys="$(aws_s3 s3api list-objects-v2 \
            --bucket "$S3_BUCKET" --prefix "${S3_PREFIX}/${sub}" \
            --query "Contents[?LastModified<'${cutoff}'].Key" --output text 2>/dev/null || true)"
  [ -n "$keys" ] && [ "$keys" != "None" ] || return 0
  for key in $keys; do
    log "pruning ${key}"
    aws_s3 s3 rm "s3://${S3_BUCKET}/${key}" || true
  done
}
log "pruning (recent>${KEEP_RECENT_DAYS}d, daily>${KEEP_DAILY_DAYS}d, weekly>${KEEP_WEEKLY_DAYS}d)…"
prune "recent/" "$KEEP_RECENT_DAYS"
prune "daily/"  "$KEEP_DAILY_DAYS"
prune "weekly/" "$KEEP_WEEKLY_DAYS"

log "done: ${file}"
ping "$HEALTHCHECK_URL"
