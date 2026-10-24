# Compose stacks (sanitized reference)

One directory per stack, one project per stack. These are **reference copies** of the live
configuration with secrets replaced by `${VARS}`, personal paths replaced by `/srv/...`, and
every exposure decision made explicit.

Differences from the live box, on purpose:

| Here | There | Why |
|---|---|---|
| `name:` on every stack | one stack still called `docker` | see [incidents](../docs/incidents.md#3-a-compose-project-named-docker) |
| `TS_IP` variable required | same, injected by `update-all.sh` | fail closed instead of binding `0.0.0.0` |
| `${DB_PASSWORD:?}` | placeholder password | secrets do not belong in git |
| `/srv/data`, `/srv/media` | `/mnt/disk-a`, `/mnt/disk-b` | paths are personal |

## Env

```bash
cp .env.example .env
$EDITOR .env          # TS_IP, DB passwords, media paths
```

`TS_IP` must be the tailnet address (`tailscale ip -4`). If it is empty, Compose aborts
instead of silently publishing the port on every interface.

## Bring up

```bash
make up               # every stack
docker compose -f nextcloud.yml up -d   # one stack
```
