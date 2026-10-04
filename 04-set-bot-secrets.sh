#!/usr/bin/env bash
# 04-set-bot-secrets.sh — run ON the VPS console. Prompts for the BotFather token and chat id.
# Does not echo the token. Stores BOT_TOKEN and TG_CHAT_ID as Actions secrets.
#   curl -fsSL https://raw.githubusercontent.com/coden607/ocs/main/04-set-bot-secrets.sh | bash
set -uo pipefail
REPO="${VPS_REPO:-coden607/ocs}"
say(){ echo "[*] $*"; }
ok(){ echo "[+] $*"; }
die(){ echo "[x] $*"; exit 1; }
[ -t 0 ] || die "need a real terminal. Run this in the DigitalOcean console, not over a pipe without a tty."
command -v gh >/dev/null || die "gh missing"
command -v curl >/dev/null || die "curl missing"
gh auth status -h github.com >/dev/null 2>&1 || die "gh is not logged in"
echo
say "BotFather: Telegram > @BotFather > /mybots > your bot > API Token"
say "Chatty bot token is the same kind of key. Paste will be hidden."
T=""
while [ -z "$T" ]; do
  printf "[?] BotFather / Chatty API token: "
  read -rs T || die "no token"
  echo
  ME=$(curl -s --max-time 20 "https://api.telegram.org/bot${T}/getMe")
  if printf '%s' "$ME" | grep -q '"ok":true'; then
    N=$(printf '%s' "$ME" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
    ok "bot @$N valid"
  else
    echo "[!] Telegram rejected that token. Copy it again from BotFather."
    T=""
  fi
done
echo
say "Open @$N, send hi, or message @userinfobot for your numeric id."
printf "[?] chat id (blank to try getUpdates): "
read -r C || C=""
if [ -z "$C" ]; then
  say "waiting up to 60s for a message to @$N"
  for i in $(seq 1 30); do
    C=$(curl -s --max-time 20 "https://api.telegram.org/bot${T}/getUpdates" | grep -o '"chat":{"id":[^,]*' | tail -1 | grep -oE '\-?[0-9]+')
    [ -n "$C" ] && break
    sleep 2
  done
fi
[ -n "$C" ] || die "no chat id"
ok "chat id: $C"
say "saving Actions secrets on $REPO"
gh secret set BOT_TOKEN -R "$REPO" -b "$T" || die "could not set BOT_TOKEN"
gh secret set TG_CHAT_ID -R "$REPO" -b "$C" || die "could not set TG_CHAT_ID"
umask 077
printf 'TOKEN=%s\nCHAT_ID=%s\nBOT_NAME=%s\n' "$T" "$C" "$N" > /root/.vpsbot.env
ok "secrets set. Reply set in chat so the workflow can be re-run."
