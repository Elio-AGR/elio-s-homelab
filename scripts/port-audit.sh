#!/usr/bin/env bash
# Print the live exposure matrix: what listens where, and whether that is
# inside the tailnet, the LAN, or loopback only.
set -euo pipefail

TS_IP="$(tailscale ip -4 2>/dev/null | head -1 || true)"

classify() {
    local addr="$1"
    case "$addr" in
        127.*|::1|localhost) echo "loopback" ;;
        "$TS_IP")            echo "tailnet" ;;
        0.0.0.0|::|'*')      echo "all-if" ;;
        *tailscale0)         echo "tailnet" ;;
        fd7a:115c:a1e0:*)    echo "tailnet" ;;   # Tailscale ULA range
        *)                   echo "other" ;;
    esac
}

printf '| %-6s | %-24s | %-10s | %s\n' "PORT" "BIND" "SCOPE" "PROCESS"
printf '|%s|%s|%s|%s\n' "--------" "--------------------------" "----------" "---------"

ss -ltnpH 2>/dev/null | while read -r _ _ _ local _ rest; do
    [[ -z "${local:-}" ]] && continue
    port="${local##*:}"
    addr="${local%:*}"
    addr="${addr%\%*}"          # strip %tailscale0 / %eth0 first
    addr="${addr#[}"; addr="${addr%]}"

    name="–"
    if [[ "$rest" == *users:* ]]; then
        name="$(sed -n 's/.*users:(("\([^"]*\)".*/\1/p' <<<"$rest")"
        [[ -z "$name" ]] && name="–"
    fi
    printf '| %-6s | %-24s | %-10s | %s\n' "$port" "${addr:-*}" "$(classify "$addr")" "$name"
done | sort -t'|' -k2,2n -u

echo
echo "Tailnet IP : ${TS_IP:-not running}"
echo "Router forwards are not visible from here — verify those from outside."
echo "Process names are only shown for your own processes; run with sudo to see root-owned ones."
