#!/usr/bin/env bash
# 02-telegram.sh — interactive Telegram setup (token, chat ID, service, verify)
set -uo pipefail
trap 'echo; exit 130' INT
say(){ echo "[*] $*"; } ok(){ echo "[+] $*"; }
warn(){ echo "[!] $*"; } die(){ echo "[x] $*"; exit 1; }
say "=== Telegram setup ==="
command -v curl >/dev/null || { apt-get update -qq && apt-get install -y -qq curl; }
E="$HOME/.vpsbot.env"; T=""; C=""
if [ -f "$E" ]; then . "$E"; say "saved setup found (bot @$BOT_NAME)"; fi
if [ -z "$T" ]; then
  echo; say "Get a token: Telegram → @BotFather → /newbot (or /mybots → API Token)"
  while [ -z "$T" ]; do
    printf "[?] paste token: "; read -r T
    ME=$(curl -s "https://api.telegram.org/bot$T/getMe")
    if printf '%s' "$ME" | grep -q '"ok":true'; then
      N=$(printf '%s' "$ME" | grep -o '"username":"[^"]*"' | cut -d'"' -f4); ok "bot @$N valid"
    else warn "bad token — copy exactly from BotFather"; T=""; fi
  done
else N="$BOT_NAME"; fi
if [ -z "$C" ]; then
  echo; say "Open @$N in Telegram, send any message (like: hi). Waiting up to 2 min..."
  for i in $(seq 1 60); do
    C=$(curl -s "https://api.telegram.org/bot$T/getUpdates" | grep -o '"chat":{"id":[^,]*' | tail -1 | grep -oE '\-?[0-9]+')
    [ -n "$C" ] && break
    printf "\r[*] waiting... %ss" $((i*2)); sleep 2
  done; echo
  if [ -z "$C" ]; then
    warn "timed out."; say "Message @userinfobot, paste your numeric ID below:"
    printf "[?] chat ID: "; read -r C
  fi
  ok "chat ID: $C"
fi
say "installing vpsbot service..."
apt-get install -y -qq python3-pip >/dev/null 2>&1
pip3 install -q --break-system-packages "python-telegram-bot==13.15" 2>/dev/null || pip3 install -q "python-telegram-bot==13.15"
mkdir -p /opt/vpsbot
curl -sf -o /opt/vpsbot/bot.py https://raw.githubusercontent.com/coden607/ocs/main/vpsbot/bot.py || die "bot.py missing in ocs repo"
cat > /etc/systemd/system/vpsbot.service << UNIT
[Unit]
Description=VPS Telegram runner
After=network.target
[Service]
Environment=VPSBOT_TOKEN=$T
Environment=VPSBOT_CHATS=$C
ExecStart=/usr/bin/python3 /opt/vpsbot/bot.py
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable --now vpsbot || die "service failed — journalctl -u vpsbot"
printf 'TOKEN=%s\nCHAT_ID=%s\nBOT_NAME=%s\n' "$T" "$C" "$N" > "$E"; chmod 600 "$E"
curl -s -X POST "https://api.telegram.org/bot$T/sendMessage" -d "chat_id=$C" --data-urlencode "text=✅ vpsbot live on $(hostname). Send me: #! echo hello && hostname" >/dev/null
echo; ok "ALL DONE — double-tap pipeline is live"
