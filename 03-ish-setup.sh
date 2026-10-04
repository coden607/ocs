#!/usr/bin/env bash
# 03-ish-setup.sh — interactive iSH helper: open all setup URLs, collect values, push to VPS
set -uo pipefail
VPS_IP="${VPS_IP:-134.122.113.44}"
E="$HOME/.vpsbot.env"
[ -f "$E" ] && . "$E"
say(){ echo "[*] $*"; } ok(){ echo "[+] $*"; } warn(){ echo "[!] $*"; }
O(){ if command -v open >/dev/null 2>&1; then open "$1"; else echo "  copy manually: $1"; fi; }
while :; do
  cat << M
=== iSH setup helper ===
  current: token=$([ -n "${TOKEN:-}" ] && echo saved || echo none)  chat=$([ -n "${CHAT_ID:-}" ] && echo saved || echo none)
1) Open BotFather (create bot / copy API token)
2) Open userinfobot (get your chat ID)
3) Save token + chat ID here
4) Push to VPS: run full Telegram setup over SSH (asks root password)
5) Open GitHub token page
6) Open Vercel token page
7) Open ocs repo
0) exit
M
  printf "[?] choice: "; read -r c
  case "$c" in
    1) O "https://t.me/BotFather"; say "send /newbot or /mybots → API Token" ;;
    2) O "https://t.me/userinfobot"; say "copy the number it sends you" ;;
    3) printf "[?] token: "; read -r TOKEN
       printf "[?] chat ID: "; read -r CHAT_ID
       printf 'TOKEN=%s\nCHAT_ID=%s\n' "$TOKEN" "$CHAT_ID" > "$E"; chmod 600 "$E"
       ok "saved to $E" ;;
    4) [ -n "${TOKEN:-}" ] || { warn "do option 3 first"; continue; }
       command -v sshpass >/dev/null 2>&1 || apk add --no-cache sshpass openssh-client >/dev/null
       printf "[?] VPS root password: "; read -rs PW; echo
       sshpass -p "$PW" ssh -t -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no root@"$VPS_IP" \
         "bash <(curl -s https://raw.githubusercontent.com/coden607/ocs/main/02-telegram.sh)" \
         && ok "setup executed on VPS" || warn "SSH failed — check password/network" ;;
    5) O "https://github.com/settings/personal-access-tokens/new" ;;
    6) O "https://vercel.com/account/tokens" ;;
    7) O "https://github.com/coden607/ocs" ;;
    0) exit 0 ;;
    *) warn "pick 0-7" ;;
  esac
  echo
done
