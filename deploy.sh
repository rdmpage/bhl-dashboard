#!/usr/bin/env bash
# Deploy to Hetzner (or any Linux server with Docker installed).
# Usage: ./deploy.sh user@your-server-ip
# Prerequisites: SSH access, Docker + Docker Compose v2 on the server.

set -euo pipefail

REMOTE="${1:?Usage: $0 user@host}"
REMOTE_DIR="/opt/bhl-dashboard"

echo "==> Syncing project files to $REMOTE:$REMOTE_DIR"
rsync -avz --exclude '.git' --exclude 'data/' \
  ./ "$REMOTE:$REMOTE_DIR/"

echo "==> Syncing data directory (SQLite files)"
# Sync the data directory separately so you can choose to skip it if the file
# is already on the server and hasn't changed.
rsync -avz --progress \
  ./data/ "$REMOTE:$REMOTE_DIR/data/"

echo "==> Starting services on $REMOTE"
ssh "$REMOTE" bash -s <<'ENDSSH'
  set -euo pipefail
  cd /opt/bhl-dashboard

  # Ensure .env exists
  if [ ! -f .env ]; then
    echo "ERROR: .env file not found on server. Create it from .env.example first."
    exit 1
  fi

  docker compose -f docker-compose.yml -f docker-compose.prod.yml pull
  docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
  docker compose -f docker-compose.yml -f docker-compose.prod.yml ps
ENDSSH

echo "==> Done. Check https://\$(ssh $REMOTE 'grep DOMAIN /opt/bhl-dashboard/.env | cut -d= -f2')"
