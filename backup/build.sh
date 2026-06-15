#!/usr/bin/env bash
# Build the custom backup accessory image and deliver it to the production host.
#
# Kamal builds the app image but NOT accessory images, and the local registry
# (localhost:5555) is only reachable from the host while `kamal deploy` holds its
# SSH tunnel open — standalone `kamal accessory boot` can't pull through it. So we
# load the image directly onto the host: `docker run` then finds it locally and
# never tries to pull. Run this before `kamal accessory boot|reboot db_backup` and
# after any change under backup/.
#
#   backup/build.sh
#   kamal accessory reboot db_backup   # picks up the freshly delivered image
#
# Override IMAGE_REF / DEPLOY_HOST via env if your config/deploy.yml differs.
set -euo pipefail

IMAGE_REF="${IMAGE_REF:-localhost:5555/drift-db-backup:latest}"
DEPLOY_HOST="${DEPLOY_HOST:-rdrift-app}"          # must match the db_backup accessory host

cd "$(dirname "$0")"

# Pin amd64 to match the production host (config/deploy.yml builder.arch).
docker build --platform linux/amd64 -t "$IMAGE_REF" .

# Keep the local registry in sync (used by the `kamal deploy` path), then deliver
# the image to the host out-of-band for `kamal accessory boot`.
docker push "$IMAGE_REF"
docker save "$IMAGE_REF" | ssh "$DEPLOY_HOST" docker load

echo "built, pushed, and delivered ${IMAGE_REF} to ${DEPLOY_HOST}"
