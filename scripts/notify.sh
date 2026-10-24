#!/usr/bin/env bash
# Shared Telegram notifier. Source this, do not execute it.
# Reads TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID from the environment
# (systemd EnvironmentFile=/etc/homelab/notify.env), never from the script.

notify() {
    local text="$1"
    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
        echo "notify: token or chat id missing, message not sent" >&2
        return 0
    fi
    curl -fsS --max-time 10 \
        -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${text}" \
        >/dev/null || echo "notify: send failed" >&2
}
