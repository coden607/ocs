#!/usr/bin/env bash
# 06-copyback.sh - run on the VPS as root. Enables the read-only /last endpoint the
# phone's "VPS copy" shortcut uses to put the last output on the clipboard.
# Binds to the Tailscale IP only (never a public port). Install Tailscale on VPS + iPhone first.
set -uo pipefail
die(){ echo "[x] $*"; exit 1; }
command -v tailscale >/dev/null || die "install Tailscale on the VPS (tailscale.com/download) and iPhone first"
IP=$(tailscale ip -4 | head -1); [ -n "$IP" ] || die "tailscale not up: run tailscale up"
TOK=$(head -c 24 /dev/urandom | base64 | tr -d '/+=')
D=/etc/systemd/system/vpsbot.service.d; mkdir -p "$D"
umask 077
cat > "$D/readback.conf" <<UNIT
[Service]
Environment=VPSBOT_READ_TOKEN=$TOK
Environment=VPSBOT_HTTP_BIND=$IP
Environment=VPSBOT_HTTP_PORT=8765
UNIT
curl -sf -o /opt/vpsbot/bot.py https://raw.githubusercontent.com/coden607/ocs/main/vpsbot/bot.py || die "bot.py fetch failed"
systemctl daemon-reload && systemctl restart vpsbot && sleep 2 && systemctl is-active --quiet vpsbot || die "vpsbot failed - journalctl -u vpsbot"
curl -sf -H "Authorization: Bearer $TOK" "http://$IP:8765/last" >/dev/null && echo "[+] endpoint OK" || die "endpoint check failed"
cat <<MSG

Shortcuts app > + > name "VPS copy":
  1. Get Contents of URL  http://$IP:8765/last
     Method GET, Headers: Authorization = Bearer $TOK
  2. Copy to Clipboard (input: Contents of URL)
Settings > Accessibility > Touch > Back Tap > Triple Tap > VPS copy
Keep the token private; it is only shown here.
MSG
