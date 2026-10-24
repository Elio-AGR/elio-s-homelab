# Incidents

Three things that went wrong, what the symptoms looked like, and what changed afterwards.
Written from the monitoring database and shell history, not from memory.

---

## 1. The outage the dashboard never reported

**Symptom:** none. No alert, no red row. The Uptime Kuma history simply had two islands:
5–12 August, then nothing until 22 October.

**What actually happened:** the host was taken offline for a full OS migration (Arch →
Debian 13). The migration was deliberate, so no alert was expected. The problem is the
shape of the evidence: ten weeks of missing checks looked exactly like ten weeks of
uptime in every query that counts heartbeats.

**Why the monitoring could not help:** Uptime Kuma runs *on the machine it monitors*, and
the alert path (cron → Telegram) runs there too. When the host dies, the monitor dies with
it, and the last thing you have is a graph that stops — which is indistinguishable from a
graph that is fine. This is the classic self-monitoring blind spot.

**What changed:**

- The gap is now a documented fact instead of an invisible assumption.
- A dead-man's-switch (external ping, alert on *absence* of a ping) is on the roadmap. The
  alert must come from a machine that is not this one.

**Lesson:** monitor the monitor. An alerting system that shares a power supply with the
thing it watches can only report failures that leave it alive.

---

## 2. The 75.7% uptime that was never real

**Symptom:** a 30-day uptime query returned 75.7% for every monitor. Six services
independent of each other, all failing at exactly the same rate — that is not a service
problem, that is a metric problem.

**Diagnosis:** the query counted heartbeats, not time:

```sql
select round(100.0 * sum(status = 1) / count(*), 2)
from heartbeat
where time > datetime('now', '-30 day');
```

Inside that 30-day window there were only ~1.2 days of heartbeats (see incident 1), and
roughly a quarter of them were recorded while the box was up but services were still
booting. So 75.7% was the ratio of good checks to *all checks that happened to exist*, not
the ratio of good time to elapsed time.

Per-day counts made it obvious:

```
2026-10-24   1116 up      0 down
2026-10-23   8552 up     38 down
2026-10-22      0 up   3060 down
2026-08-12      4 up      2 down
2026-08-11   1637 up      1 down
```

**What changed:** uptime is now reported against elapsed time with gaps called out, and the
30-day number is never quoted without the coverage next to it. Since the stack came back at
01:04 on 23 October, all six monitors have been at 100%.

**Lesson:** a ratio over "the rows that exist" is not a ratio over time. Missing data is not
good data — the query has to say which one it means.

---

## 3. A Compose project named `docker`

**Symptom:** `docker ps` printed `docker-db-1` and `docker-nextcloud-1`, while every other
container had a clean name (`gitea`, `jellyfin`, `netdata`). `docker compose ls` showed a
project literally called `docker`.

**Cause:** the Nextcloud stack lived in `~/docker/nextcloud` with `name: docker` at the top
of its compose file. Compose derived container names from the project name, and the name was
chosen for the folder, not for the stack.

**Why it matters more than aesthetics:** the monitoring script checks containers by name.
A rename changes `docker-db-1` to something else, the check stops matching, and the alerting
for those two containers fails *silently* — the worst possible failure mode for a monitor.
Generic names also make `docker compose ls` useless as an inventory.

**Fix applied:** new stacks set `name:` to the service (`nextcloud`, `gitea`, `jellyfin`).
The existing stack is left alone until the monitoring script is updated in the same commit;
renaming it first would blind the checks for the database and the app at the same time.

**Lesson:** infrastructure names are an interface. Anything a script greps for is an API,
and renaming it is a breaking change that needs the same care as a code change.
