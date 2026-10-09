#!/usr/bin/env bash
# 00-all.sh - everything in one command, run on the VPS as root:
#   curl -fsSL https://raw.githubusercontent.com/coden607/ocs/main/00-all.sh | bash
# Bot install (02) -> shortcut recipe to Telegram (07) -> optional return tap (06, needs Tailscale).
set -uo pipefail
R=https://raw.githubusercontent.com/coden607/ocs/main
run(){ echo; echo "=== $1 ==="; curl -fsSL "$R/$1" | bash; }
run 02-telegram.sh || { echo "[x] 02 failed - fix that first"; exit 1; }
run 07-backtap.sh || { echo "[x] 07 failed"; exit 1; }
if command -v tailscale >/dev/null && tailscale ip -4 >/dev/null 2>&1; then
  run 06-copyback.sh || echo "[!] 06 failed (optional)"
else
  echo; echo "[*] Skipping 06-copyback (needs Tailscale on VPS + iPhone). Optional."
fi
echo; echo "[+] Done. Open your bot chat in Telegram, build the shortcut from the copy boxes,"
echo "    then Settings > Accessibility > Touch > Back Tap > Double Tap > VPS run."
