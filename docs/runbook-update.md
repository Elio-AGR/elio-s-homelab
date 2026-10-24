# Runbook: updates

## Routine update

```bash
cd ~/docker
./update-all.sh
```

`update-all.sh` walks every Compose project, runs `docker compose pull` then
`up -d`, and prunes dangling images at the end. It exports `TS_IP=$(tailscale ip -4 | head -1)`
first, because two stacks bind to the tailnet address through that variable — if it is
empty, Compose refuses to start instead of binding to `0.0.0.0`. That failure mode is
intentional.

## Why one script instead of Watchtower

Watchtower is convenient and I do not use it on purpose:

- Updates arrive at a time nobody chose; a bad `:latest` lands at 03:00 and the first
  symptom is a 502 in the morning.
- Rollback is implicit (the old image is already gone).
- Some images need a migration step (`nextcloud` upgrades its schema on first boot), and
  those need to be watched.

Manual pull-then-up gives a human in the loop, a known time, and an obvious rollback:
the previous image tag is still in `docker images` until the prune.

## Update order

1. Backups first — confirm last night's run exists.
2. `nextcloud` + `db` together, and never the app without the database.
3. Everything else, any order.
4. `netdata` and `portainer` last, they are the observability of the operation itself.

## Rollback

```bash
docker compose -f compose/jellyfin.yml down
docker tag <previous-image-id> jellyfin/jellyfin:latest
docker compose -f compose/jellyfin.yml up -d
```

Not elegant, which is exactly why the roadmap says pin digests instead of `:latest`. With a
digest in the compose file, rollback is a one-line edit and a re-up.

## OS updates

```bash
sudo apt update && sudo apt full-upgrade
sudo reboot            # kernel upgrades only apply after this
```

Reboot is announced to Telegram by the unit, and the bot comes back with the machine, so
the box is reachable again without physical access.

## Post-update check

```bash
make audit                       # ports as expected
curl -sf localhost:8090/health   # 200
systemctl --user --failed        # empty
docker ps --filter status=restarting
```
