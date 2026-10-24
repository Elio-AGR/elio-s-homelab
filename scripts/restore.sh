#!/usr/bin/env bash
# Restore files from the latest backup. Deliberately stops before touching
# containers: restoring an old database over a newer one is a data-loss bug.
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/srv/backup/latest}"
DOCKER_DIR="${DOCKER_DIR:-$HOME/docker}"
SCRIPT_DIR="${SCRIPT_DIR:-$HOME/server-script}"

[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }
[[ -d "$BACKUP_DIR" ]] || { echo "no backup at $BACKUP_DIR"; exit 1; }

echo "backup: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"
read -rp "This overwrites $DOCKER_DIR and $SCRIPT_DIR. Continue? (y/N) " ok
[[ "$ok" == "y" ]] || { echo "cancelled"; exit 0; }

echo "[1/5] docker projects"
rm -rf "$DOCKER_DIR"
tar -xzf "$BACKUP_DIR/docker.tar.gz" -C "$(dirname "$DOCKER_DIR")"

echo "[2/5] server scripts"
rm -rf "$SCRIPT_DIR"
tar -xzf "$BACKUP_DIR/server-script.tar.gz" -C "$(dirname "$SCRIPT_DIR")"

echo "[3/5] systemd units"
tar -xzf "$BACKUP_DIR/systemd.tar.gz" -C /
systemctl daemon-reload

echo "[4/5] crontab"
crontab -u "${SUDO_USER:-$USER}" "$BACKUP_DIR/crontab.txt"

echo "[5/5] permissions"
OWNER="${SUDO_USER:-$USER}"
chown -R "$OWNER":"$OWNER" "$DOCKER_DIR" "$SCRIPT_DIR"
chmod +x "$SCRIPT_DIR"/*.sh

cat <<'EOF'

Files restored. Remaining manual steps:
  1. docker compose -f compose/nextcloud.yml up -d
  2. gunzip -c .../database/nextcloud.sql.gz | docker exec -i docker-db-1 mysql -u root -p nextcloud
  3. docker ps   # confirm every container is back
EOF
