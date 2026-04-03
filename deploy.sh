#!/usr/bin/env bash
# Deploy to Hetzner (or any Linux server with Docker installed).
# Usage: ./deploy.sh user@your-server-ip
# Prerequisites: SSH access, Docker + Docker Compose v2 on the server.

set -euo pipefail

REMOTE="${1:?Usage: $0 user@host}"
REMOTE_DIR="/opt/bhl-dashboard"

# Ensure .env exists on the server
ssh "$REMOTE" "test -f $REMOTE_DIR/.env || (echo 'ERROR: $REMOTE_DIR/.env not found on server. Create it from .env.example first.' && exit 1)"

echo "==> Syncing project files to $REMOTE:$REMOTE_DIR"
rsync -avz --exclude '.git' --exclude 'data/' --exclude 'metabase-data/' \
  ./ "$REMOTE:$REMOTE_DIR/"

echo "==> Syncing data directory (SQLite files)"
rsync -avz --progress \
  ./data/ "$REMOTE:$REMOTE_DIR/data/"

echo "==> Stopping Metabase to safely sync state"
ssh "$REMOTE" "cd $REMOTE_DIR && docker compose stop metabase"

echo "==> Syncing Metabase state (dashboards, queries)"
rsync -avz ./metabase-data/ "$REMOTE:$REMOTE_DIR/metabase-data/"

echo "==> Starting services on $REMOTE"
ssh "$REMOTE" bash -s <<'ENDSSH'
  set -euo pipefail
  cd /opt/bhl-dashboard

  docker compose -f docker-compose.yml -f docker-compose.prod.yml pull --quiet
  docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
  docker compose -f docker-compose.yml -f docker-compose.prod.yml ps
ENDSSH

echo "==> Done."
