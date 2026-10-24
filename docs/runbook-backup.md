# Runbook: backup and restore

## What runs

| Time | Script | Contents |
|---|---|---|
| 20:00 | `backup.sh` | Docker projects, scripts, systemd units, crontab, Nextcloud SQL dump, manifest |
| 20:10 | `backup_extra.sh` | Photos and configs that live outside the Docker tree |

Destination: `/mnt/disk-b/Archive/server-backup/auto/latest` — a **different physical disk**
from the one holding the data. A backup on the same spindle as the data is a copy, not a
backup.

Each run rewrites `latest/` from scratch and writes `backup.log` with:

```
Hostname / Date / OS / Docker version / Compose version
Files:  docker.tar.gz  server-script.tar.gz  systemd.tar.gz  crontab.txt  database/nextcloud.sql.gz
Total size
```

The script uses `set -euo pipefail` and an `ERR` trap that messages the current step to
Telegram. A failure anywhere — a full disk, a dead container, a missing `mysqldump` — is
loud instead of leaving a half-written archive that looks fine.

## Verify a backup without restoring it

```bash
cd /mnt/disk-b/Archive/server-backup/auto/latest
tar -tzf docker.tar.gz | head            # archive is readable
tar -tzf docker.tar.gz | wc -l           # file count is in the expected range
zcat database/nextcloud.sql.gz | tail -5 # dump ends with "Dump completed"
```

The last line matters: a `mysqldump` that died halfway still produces valid gzip.

## Restore

RPO 24 h (worst case: lose today's changes). RTO ~30 min on the same hardware.

```bash
sudo ./scripts/restore.sh          # asks for confirmation, lists what it will overwrite
docker compose -f compose/nextcloud.yml up -d
gunzip -c .../database/nextcloud.sql.gz | docker exec -i docker-db-1 mysql -u root -p nextcloud
```

The restore script deliberately stops after putting files back and prints the remaining
manual steps. Fully automated restore is a footgun: it can silently restore an old database
over a newer one.

## Drill checklist

Run this before trusting the backup with anything important:

- [ ] Pick a scratch VM (or a spare disk) and boot a minimal Debian.
- [ ] Copy `latest/` over, run `restore.sh`, start the stacks.
- [ ] Log in to Gitea, Nextcloud and Jellyfin; open one file, one repo, one video.
- [ ] Record wall-clock time: that number is the real RTO.
- [ ] Note anything that was missing from the archive and add it to `backup.sh`.

## Known weaknesses

1. **Permissions are broad.** The finished tree is `chmod -R 755` with `644` files, so the
   Nextcloud dump is readable by any local user. Fix: `700`/`600` plus an owner group.
2. **No off-site copy.** One house fire, one flood, or one stolen disk and both copies are
   gone. Fix: `restic` to object storage, encrypted, nightly.
3. **No automated restore test.** The script exists; a scheduled drill does not. Until the
   checkbox above has real numbers next to it, RTO is an estimate, not a measurement.
