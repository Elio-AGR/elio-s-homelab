#!/usr/bin/env bash
# One-screen status for the whole box. Exit 1 if anything is down,
# so it can also be used by a monitor or a cron alert.
set -uo pipefail
fail=0

printf '%-22s %-12s %s\n' "CONTAINER" "STATE" "HEALTH"
while read -r name state health; do
    printf '%-22s %-12s %s\n' "$name" "$state" "${health:-–}"
    [[ "$state" == "running" ]] || fail=1
    [[ "$health" == "unhealthy" ]] && fail=1
done < <(docker ps -a --format '{{.Names}} {{.State}} {{.Status}}' \
         | awk '{print $1, $2, ($0 ~ /unhealthy/ ? "unhealthy" : ($0 ~ /healthy/ ? "healthy" : "-"))}')

echo
printf '%-12s %s\n' "ENDPOINT" "HTTP"
for url in http://127.0.0.1:8090/ http://127.0.0.1:3001 http://127.0.0.1:8085; do
    code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$url" || echo 000)"
    printf '%-12s %s\n' "${url##*:}" "$code"
    [[ "$code" =~ ^[23] ]] || fail=1
done

echo
echo "load: $(cut -d' ' -f1-3 /proc/loadavg)   ram: $(free -h | awk '/Mem:/{print $3"/"$2}')   disk: $(df -h / | awk 'NR==2{print $5}')"
exit "$fail"
