#!/usr/bin/env bash
# 02-telegram.sh - Telegram setup (token, chat ID, service, verify)
# Non-interactive when VPSBOT_TOKEN and VPSBOT_CHATS are set (GitHub Actions).
set -uo pipefail
trap 'echo; exit 130' INT
say(){ echo "[*] $*"; }
ok(){ echo "[+] $*"; }
warn(){ echo "[!] $*"; }
die(){ echo "[x] $*"; exit 1; }
say "=== Telegram setup ==="
command -v curl >/dev/null || { apt-get update -qq && apt-get install -y -qq curl; }
E="$HOME/.vpsbot.env"
T="${VPSBOT_TOKEN:-}"
C="${VPSBOT_CHATS:-}"
if [ -f "$E" ]; then . "$E"; T="${VPSBOT_TOKEN:-${TOKEN:-$T}}"; C="${VPSBOT_CHATS:-${CHAT_ID:-$C}}"; say "saved setup found (bot ${BOT_NAME:-unknown})"; fi
if [ -z "$T" ]; then
  [ -t 0 ] || die "VPSBOT_TOKEN empty and no terminal. Set the BOT_TOKEN secret."
  echo; say "Get a token: Telegram > @BotFather > /newbot (or /mybots > API Token)"
  while [ -z "$T" ]; do
    printf "[?] paste token: "; read -r T || die "no token"
    ME=$(curl -s "https://api.telegram.org/bot$T/getMe")
    if printf '%s' "$ME" | grep -q '"ok":true'; then
      N=$(printf '%s' "$ME" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
      ok "bot @$N valid"
    else
      warn "bad token - copy exactly from BotFather"; T=""
    fi
  done
else
  ME=$(curl -s "https://api.telegram.org/bot$T/getMe")
  N=$(printf '%s' "$ME" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
  printf '%s' "$ME" | grep -q '"ok":true' || die "BOT_TOKEN rejected by Telegram"
  ok "bot @$N valid"
fi
if [ -z "$C" ]; then
  [ -t 0 ] || die "VPSBOT_CHATS empty and no terminal. Set the TG_CHAT_ID secret."
  echo; say "Open @$N in Telegram, send any message (like: hi). Waiting up to 2 min..."
  for i in $(seq 1 60); do
    C=$(curl -s "https://api.telegram.org/bot$T/getUpdates" | grep -o '"chat":{"id":[^,]*' | tail -1 | grep -oE '\-?[0-9]+')
    [ -n "$C" ] && break
    printf "\r[*] waiting... %ss" $((i*2)); sleep 2
  done; echo
  if [ -z "$C" ]; then
    warn "timed out."; say "Message @userinfobot, paste your numeric ID below:"
    printf "[?] chat ID: "; read -r C || die "no chat id"
  fi
  ok "chat ID: $C"
fi
say "installing vpsbot service..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq python3-venv python3-pip >/dev/null 2>&1
mkdir -p /opt/vpsbot
rm -rf /opt/vpsbot/venv
python3 -m venv /opt/vpsbot/venv || die "venv failed"
/opt/vpsbot/venv/bin/pip install -q "python-telegram-bot==13.15" "urllib3<2" "setuptools<81" || die "pip failed"
curl -sf -o /opt/vpsbot/bot.py https://raw.githubusercontent.com/coden607/ocs/main/vpsbot/bot.py || die "bot.py missing in ocs repo"
cat > /etc/systemd/system/vpsbot.service << UNIT
[Unit]
Description=VPS Telegram runner
After=network.target
[Service]
Environment=VPSBOT_TOKEN=$T
Environment=VPSBOT_CHATS=$C
ExecStart=/opt/vpsbot/venv/bin/python /opt/vpsbot/bot.py
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable --now vpsbot || die "service failed - journalctl -u vpsbot"
sleep 2
systemctl is-active --quiet vpsbot || die "vpsbot not active - journalctl -u vpsbot"
printf 'TOKEN=%s\nCHAT_ID=%s\nBOT_NAME=%s\n' "$T" "$C" "$N" > "$E"; chmod 600 "$E"
curl -s -X POST "https://api.telegram.org/bot$T/sendMessage" -d "chat_id=$C" --data-urlencode "text=OK vpsbot live on $(hostname). Send me: #! echo hello && hostname" >/dev/null
echo; ok "ALL DONE - double-tap pipeline is live"
