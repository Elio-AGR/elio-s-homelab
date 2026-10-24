#!/usr/bin/env bash
# Nightly backup. Every step is named so a failure reports WHERE it died,
# not just that something went wrong.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=notify.sh
source "$HERE/notify.sh"

BACKUP_DIR="${BACKUP_DIR:-/srv/backup/latest}"
DOCKER_DIR="${DOCKER_DIR:-$HOME/docker}"
SCRIPT_DIR="${SCRIPT_DIR:-$HOME/server-script}"
DATA_DIR="${DATA_DIR:-/srv/data}"
KEEP_DAYS="${KEEP_DAYS:-7}"

STEP="startup"
on_error() {
    notify "Backup FAILED
host: $(hostname)
step: ${STEP}
time: $(date -Is)"
    echo "backup failed at: ${STEP}" >&2
}
trap on_error ERR

STEP="prepare"
rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR/database"
echo "===== backup $(date -Is) =====" > "$BACKUP_DIR/backup.log"

STEP="docker projects"
tar -czf "$BACKUP_DIR/docker.tar.gz" -C "$(dirname "$DOCKER_DIR")" "$(basename "$DOCKER_DIR")"

STEP="server scripts"
tar --exclude='venv' --exclude='.git' -czf "$BACKUP_DIR/server-script.tar.gz" \
    -C "$(dirname "$SCRIPT_DIR")" "$(basename "$SCRIPT_DIR")"

STEP="systemd units"
tar -czf "$BACKUP_DIR/systemd.tar.gz" -C /etc/systemd system

STEP="crontab"
crontab -l > "$BACKUP_DIR/crontab.txt" 2>/dev/null || echo "no crontab" > "$BACKUP_DIR/crontab.txt"

STEP="nextcloud database"
if docker ps --format '{{.Names}}' | grep -qx 'docker-db-1'; then
    docker exec docker-db-1 sh -c 'exec mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' \
        | gzip > "$BACKUP_DIR/database/nextcloud.sql.gz"
fi

STEP="manifest"
{
    echo
    echo "host     : $(hostname)"
    echo "date     : $(date -Is)"
    echo "os       : $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
    echo "docker   : $(docker --version)"
    echo "compose  : $(docker compose version --short 2>/dev/null || echo n/a)"
    echo
    echo "files:"
    du -sh "$BACKUP_DIR"/*
} >> "$BACKUP_DIR/backup.log"

STEP="permissions"
chmod -R go-rwx "$BACKUP_DIR"   # backups contain credentials

STEP="notify"
SIZE="$(du -sh "$BACKUP_DIR" | awk '{print $1}')"
notify "Backup OK
host: $(hostname)
size: ${SIZE}
path: ${BACKUP_DIR}
$(date -Is)"
echo "backup ok: ${SIZE}"
