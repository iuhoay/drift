# Custom database-backup accessory for Drift.
#
# Built ONLY on official images/tools:
#   - postgres:16  — the official Postgres image (same major as the `db`
#     accessory, so pg_dump/pg_restore versions match the server).
#   - AWS CLI v2    — AWS's official CLI, installed from AWS's own installer,
#     used to upload dumps to S3-compatible storage (Cloudflare R2 / Backblaze B2).
#
# No third-party container images are used.
#
# Build & push to the Kamal registry, then boot the accessory:
#   backup/build.sh
#   kamal accessory boot db_backup
FROM postgres:16

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl unzip ca-certificates \
 && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscliv2.zip \
 && unzip -q /tmp/awscliv2.zip -d /tmp \
 && /tmp/aws/install \
 && rm -rf /tmp/aws /tmp/awscliv2.zip \
 && apt-get purge -y unzip \
 && apt-get autoremove -y \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Path-style addressing is the safe universal default for S3-compatible
# providers (R2 / B2). Baked in so it applies to scheduled runs and ad-hoc execs.
RUN aws configure set default.s3.addressing_style path

COPY db-backup.sh   /usr/local/bin/db-backup
COPY db-restore.sh  /usr/local/bin/db-restore
COPY entrypoint.sh  /usr/local/bin/backup-entrypoint
RUN chmod +x /usr/local/bin/db-backup /usr/local/bin/db-restore /usr/local/bin/backup-entrypoint

ENTRYPOINT ["/usr/local/bin/backup-entrypoint"]
