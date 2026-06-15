#!/usr/bin/env bash
# Accessory entrypoint: run a backup on boot, then on a fixed interval.
#
# A plain sleep loop (no cron) keeps the image dependency-free and inherits the
# container's env directly. Interval defaults to 4h; override with
# BACKUP_INTERVAL_SECONDS. A failed run is logged but never stops the loop.
set -uo pipefail

INTERVAL="${BACKUP_INTERVAL_SECONDS:-14400}"   # 4 hours
echo "[backup-accessory] starting; interval=${INTERVAL}s"

while true; do
  /usr/local/bin/db-backup || echo "[backup-accessory] backup run failed (exit $?)"
  sleep "$INTERVAL"
done
