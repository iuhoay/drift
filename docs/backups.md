# Database backups

Drift backs up its production database with periodic logical dumps pushed to
S3‑compatible object storage (Cloudflare R2 / Backblaze B2). It runs as a
**Kamal accessory** — a sidecar container next to the `db` accessory, managed by
the same `kamal` workflow as everything else. Tooling lives in [`backup/`](../backup).

## Why an accessory (and not a host cron or the Rails app)

- **Kamal‑managed, low‑touch.** Config lives in `config/deploy.yml`; lifecycle is
  `kamal accessory boot|reboot|logs db_backup`. No host systemd/rclone to install.
- **Isolated failure domain.** It's a separate container from the web app, so a
  broken deploy, an OOM, or a wedged Solid Queue can't stop backups. (Solid Queue
  runs inside Puma here — an in‑app backup job would share that fate.)
- **Official images only.** The image is built from the official `postgres:16`
  (so `pg_dump`/`pg_restore` match the server major) plus AWS's official CLI v2.
  No third‑party images.

## What is backed up — and what isn't

Production runs five logical databases in the single `drift-db` Postgres
accessory. Only one holds irreplaceable data:

| Database | Contents | Backed up |
| --- | --- | --- |
| `drift_production` | users, sessions, subscriptions, **per‑user read/starred state**, entries | **Yes** |
| `drift_production_cache` | Solid Cache | No — regenerates |
| `drift_production_queue` | Solid Queue jobs | No — `RefreshDueFeedsJob` re‑enqueues |
| `drift_production_cable` | Solid Cable | No — ephemeral |
| `drift_production_rails_pulse` | metrics | No — disposable |

Roles (`root`, `drift`) come from [`docker/postgres-init.sql`](../docker/postgres-init.sql),
so the `drift_production` dump **plus this repo** fully reconstitute production.
Active Storage is unused, so no file volume needs backing up.

## How it works

The image ([`backup/Dockerfile`](../backup/Dockerfile)) runs a backup on boot,
then every `BACKUP_INTERVAL_SECONDS` (default 4h). Each run
([`backup/db-backup.sh`](../backup/db-backup.sh)):

1. `pg_dump -Fc` of `drift_production` over the Kamal network (`PG_HOST=drift-db`).
2. **Verifies** the archive with `pg_restore --list` — a corrupt dump never uploads.
3. Uploads to `recent/`, and promotes the **first run of each day** to `daily/`
   and the **first run of each ISO week** to `weekly/`.
4. Prunes each tier by age.

### Retention (defaults, tune in `config/deploy.yml`)

| Tier | Cadence | Kept (`*_DAYS`) | Approx. count |
| --- | --- | --- | --- |
| `recent/` | every 4 h | `KEEP_RECENT_DAYS=3` | ~18 |
| `daily/` | first run/day | `KEEP_DAILY_DAYS=30` | ~30 |
| `weekly/` | first run/week | `KEEP_WEEKLY_DAYS=180` | ~26 |

## Setup (one time)

1. **Bucket + token.** Create a bucket in Cloudflare R2 or Backblaze B2 and an API
   token/key scoped to it.
2. **Secrets.** Store the key in 1Password as `op://rDrift/R2/access_key_id` and
   `op://rDrift/R2/secret_access_key` (already referenced from
   [`.kamal/secrets`](../.kamal/secrets)).
3. **Endpoint.** In `config/deploy.yml`, set the `db_backup` accessory's
   `S3_ENDPOINT` (and `AWS_DEFAULT_REGION`):
   - R2: `https://<accountid>.r2.cloudflarestorage.com`, region `auto`.
   - B2: `https://s3.<region>.backblazeb2.com`, region e.g. `us-west-004`.
   Adjust `S3_BUCKET`/`S3_PREFIX` if yours differ.
4. **Build, deliver, boot:**
   ```bash
   backup/build.sh                    # build + push + deliver the image to the host
   kamal accessory boot db_backup     # start it
   ```
   > Kamal's local registry (`localhost:5555`) is only reachable from the host
   > during a `kamal deploy` SSH tunnel, so standalone `kamal accessory boot`
   > can't pull through it. `build.sh` therefore also `docker save | ssh | docker
   > load`s the image onto `DEPLOY_HOST`; `docker run` then finds it locally. If
   > you use a registry the host can reach directly, drop that step.

### Verify it works

```bash
kamal accessory logs db_backup -f                       # watch the boot-time run
kamal accessory exec db_backup --reuse "db-backup"      # trigger an ad-hoc run
aws --endpoint-url <S3_ENDPOINT> s3 ls s3://rdrift-db/rdrift/recent/
```

### Updating

After editing anything in `backup/`, rebuild and reboot:
```bash
backup/build.sh && kamal accessory reboot db_backup
```

## Restore

### Rehearse (safe — scratch DB, do this periodically)

A backup you haven't restored is a hypothesis. The restore defaults to a
throwaway `drift_restore_check` database, so this never touches production:

```bash
# newest backup → drift_restore_check (FORCE=1 skips the typed confirmation)
latest=$(kamal accessory exec db_backup --reuse \
  "aws --endpoint-url \$S3_ENDPOINT s3 ls s3://\$S3_BUCKET/\$S3_PREFIX/recent/ | awk '{print \$4}' | sort | tail -1")
kamal accessory exec db_backup --reuse "FORCE=1 db-restore recent/${latest}"
```

Drop the scratch DB afterwards:
```bash
kamal accessory exec db_backup --reuse \
  "psql -h drift-db -U root -d postgres -c 'DROP DATABASE drift_restore_check;'"
```

### Real recovery (production)

Postgres can't drop a database with live connections, so stop the app first:

```bash
kamal app stop
kamal accessory exec db_backup --reuse "FORCE=1 TARGET_DB=drift_production db-restore daily/2026-06-15.dump"
kamal app boot
```

For a host‑loss rebuild: provision the new server, `kamal setup` (recreates the
`drift-db` accessory and roles via `postgres-init.sql`), `backup/build.sh`, boot
`db_backup`, then run the recovery above against a recent dump.

## Monitoring

Set `HEALTHCHECK_URL` (a [healthchecks.io](https://healthchecks.io)-style check)
in the accessory env to be alerted when backups *stop* — each success pings the
URL, each failure pings `…/fail`. Silent backup failure is how most backup plans
actually die.

## Stronger guarantees (optional, not configured)

Recovery point today is "up to ~4 hours." If that's ever too loose, the next step
is **WAL archiving for point‑in‑time recovery** (`pgBackRest` / WAL‑G against the
same bucket), reaching minutes. It's meaningfully more setup; for an RSS reader
whose entries refetch themselves, the sub‑daily logical dump here is the right trade.
