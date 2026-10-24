# Network and exposure

## Port matrix

| Port | Service | Bind | Reachable from | Verified |
|---|---|---|---|---|
| 22 | OpenSSH | `0.0.0.0` | LAN + tailnet | yes |
| 222 | Gitea SSH | `0.0.0.0` | LAN + tailnet | yes |
| 3000 | Gitea HTTP | `0.0.0.0` | LAN | yes |
| 3001 | Uptime Kuma | `0.0.0.0` | LAN | yes |
| 8080 | Nextcloud | `0.0.0.0` | LAN | yes |
| 8085 | Dashboard | `0.0.0.0` | LAN | yes |
| 8090 | Healthcheck | `0.0.0.0` | LAN | yes |
| 8096 | Jellyfin | `0.0.0.0` | LAN | yes |
| 8765 | Agent dashboard | `127.0.0.1` | host only | yes |
| 19999 | Netdata | tailscale IP | tailnet | yes |
| 9000 | Portainer | tailscale IP | tailnet | yes |
| 49713 | Agent gateway API | `127.0.0.1` | host only | yes |

`0.0.0.0` means "every interface on this machine", which is why the LAN tier is a network
decision, not a host one: the host firewall is intentionally left off, and isolation is
enforced upstream. That trade-off is documented in `security.md`; the honest summary is
that a laptop which joins an untrusted network is exposed until the bind addresses change.

## Why Tailscale instead of a port-forward

| | Port-forward + TLS | Tailscale |
|---|---|---|
| Public attack surface | Every forwarded port | None |
| Certificate management | Required, renewal breaks silently | None |
| Auth | App-level only | Device keys + app-level |
| Works behind CGNAT | No | Yes |
| Cost | Domain + VPS/VPN | Free tier is enough |

A port-forward means every service is reachable by every scanner on the internet, and it
only takes one unpatched Nextcloud to lose the data. Tailscale moves the trust boundary to
device identity, which is a much smaller thing to defend.

## Verification

Isolation claims are only worth what the test behind them is worth. The check I run:

```bash
# from the host: what is actually listening
ss -ltnp | sort -k4

# from a device on the same LAN
for p in 3000 3001 8080 8085 8090 8096; do
  timeout 2 bash -c "</dev/tcp/<lan-ip>/$p" && echo "$p open" || echo "$p closed"
done

# from a mobile connection (outside the LAN)
curl -m 3 -sv http://<public-ip>:3000 2>&1 | tail -3
```

Last verified: **2026-10-24**, from a second device on the LAN (services reachable) and
from a mobile connection outside it (all six ports time out, no route). Result: LAN-only as
intended.

`make audit` regenerates the matrix from the live machine so the table and reality cannot
drift apart silently.

## DNS and naming

- LAN: mDNS/hostname resolution only, plus `/etc/hosts` entries on client devices.
- Tailnet: MagicDNS names, so `ssh <host>` and `http://<host>:9000` work from any device
  signed into the tailnet without hardcoded IPs.
- No public DNS records point at this server.

## What I would change

1. Bind every LAN-tier service to the tailnet interface, then delete the LAN tier. The
   only reason it exists is convenience on the couch.
2. Put the two nginx dashboards behind one small reverse proxy with basic auth, so the
   LAN tier stops being anonymous.
3. Add a second uplink path (LTE fallback) before trusting the box with anything critical.
