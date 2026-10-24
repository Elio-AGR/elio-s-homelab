# Security

## Threat model

| Adversary | Capability | What stops them |
|---|---|---|
| Someone on the same Wi-Fi | Can reach LAN-tier ports | LAN isolation (verified), no anonymous admin panels |
| Internet scanner | Can reach only what the router forwards | No port-forward, no public DNS, no tunnel |
| Someone who finds the Telegram bot | Can message it | Allowlist on `effective_user.id`, every handler wrapped |
| A compromised container | Runs code on the host network | Per-service mounts, no shared volumes, Docker socket only where required |
| Lost/stolen laptop | Physical access | Full-disk encryption at boot, Tailscale keys revocable per device |
| Me, at 2 a.m. | `rm -rf` with good intentions | Nightly backups to a separate disk, restore script with confirmation |

## Findings

### F1 — Bot token hardcoded in three scripts (fixed in this repo)

`backup.sh`, `docker_monitor.sh` and `daily_report.sh` each embedded the same Telegram bot
token and chat ID. Anyone with read access to `~/server-script` — a backup archive, a
screenshot, a pasted log — had full control of the bot.

**Fix:** every script reads `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` from an environment
file outside git. The token is rotated after the change, because a secret that has been in
a file is a secret that has been copied.

```bash
# /etc/homelab/notify.env   (root:root, 0600)
TELEGRAM_BOT_TOKEN=...
TELEGRAM_CHAT_ID=...
```

### F2 — Weak default database password (open)

The Nextcloud MariaDB credentials were set to placeholder values when the stack was first
built and never rotated. The database port is not published, so the exposure is limited to
containers on the same host — but "not exposed" is not a password policy.

**Fix:** generate a 32-character password, update `.env`, restart `db` then `nextcloud`.

### F3 — Portainer has a read-write Docker socket (accepted)

A container with `/var/run/docker.sock` mounted read-write can start a privileged container
and own the host. Portainer needs it to manage stacks, so the control is not the mount, it
is who can reach the UI: tailnet-only, behind Tailscale device auth, no LAN route.

**Accepted, with monitoring:** if the Portainer UI ever appears on a LAN port, that is an
incident, not a configuration change.

### F4 — Netdata runs with `SYS_PTRACE` and unconfined AppArmor (accepted)

It reads host `/proc` and `/sys` to produce per-second metrics; without the capability it
reports almost nothing. Same containment argument as F3: tailnet-only, and it is the
observability layer, so it is the last thing to lose access to.

### F5 — LAN-tier services bind `0.0.0.0` with no host firewall (mitigated upstream)

The host firewall is off; isolation is enforced by the network (no route from outside, no
forward). This is a real weakness: join an untrusted Wi-Fi and six services are one ARP
table away from a stranger.

**Fix on the roadmap:** bind to the tailnet address and drop the LAN tier, or enable `ufw`
with an allowlist of the local subnet. Either one closes it; doing both is better.

### F6 — No TLS on LAN services (accepted)

HTTP on the LAN, WireGuard encryption on the tailnet. A passive attacker on the LAN could
read a Nextcloud session; the LAN is assumed trusted, which is exactly the assumption F5
breaks. Same fix.

## The Telegram bot

It is a remote shell with a nice UI, so it gets the most scrutiny:

```python
def restricted(func):
    async def wrapper(update, context):
        if update.effective_user.id != CHAT_ID:
            await update.message.reply_text("Unauthorized")
            return
        return await func(update, context)
    return wrapper
```

- **Allowlist, not obscurity.** The check is on the numeric user ID, not the username,
  which cannot be re-registered by someone else.
- **Every handler is decorated.** A new command that forgets `@restricted` is unauthenticated — this is the failure to watch for in review.
- **`shell=True` is the real risk.** Commands are built from fixed strings, not from message
  text, so there is no injection path today. That property must survive every future
  command.
- **Account takeover is the threat.** The bot trusts Telegram's identity, so the security of
  the server depends on the security of one Telegram account. 2FA on that account is not
  optional.
- **Destructive commands are reachable.** `/reboot` and `/shutdown` are one tap away. The
  mitigation is that they are useful; the residual risk is a fat finger, which backups and
  an IPMI-less reboot cycle cover.

## Hardening checklist

- [x] No secrets in git; `.env.example` only
- [x] Bot commands allowlisted by numeric user ID
- [x] Admin UIs (Portainer, Netdata) on the tailnet, not the LAN
- [x] Backups on a separate physical disk, with an error trap that notifies
- [ ] Rotate the database password (F2)
- [ ] Move to `EnvironmentFile=` for every unit, no inline tokens anywhere
- [ ] Drop `:latest` in favour of pinned digests
- [ ] Enable `ufw` or bind LAN services to the tailnet (F5)
- [ ] Off-site encrypted backup copy
- [ ] External dead-man's-switch for host-down alerts
