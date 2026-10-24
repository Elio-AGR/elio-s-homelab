#!/usr/bin/env bash
# Rebuild the base system on a fresh Debian 13. Idempotent: safe to re-run.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }

echo "[1/5] base packages"
apt-get update
apt-get install -y ca-certificates curl gnupg git jq htop rsync smartmontools lm-sensors

echo "[2/5] docker engine + compose plugin"
if ! command -v docker >/dev/null; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker

echo "[3/5] directories"
install -d -o "${SUDO_USER:-root}" -g "${SUDO_USER:-root}" \
    /srv/data /srv/media /srv/backup /etc/homelab

echo "[4/5] secrets file"
if [[ ! -f /etc/homelab/notify.env ]]; then
    install -m 0600 -o root -g root /dev/null /etc/homelab/notify.env
    cat > /etc/homelab/notify.env <<'EOF'
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
EOF
    echo "  filled /etc/homelab/notify.env (mode 0600) - add your token"
fi

echo "[5/5] tailscale"
if ! command -v tailscale >/dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
fi
echo "  next: sudo tailscale up --ssh"

echo
echo "done. next: cp compose/.env.example compose/.env && make up"
