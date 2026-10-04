#!/usr/bin/env bash
# 01-vps-key.sh — run ON the VPS as root. Creates the Actions key, installs it, stores the private key as a GitHub secret.
# One line from the droplet console:
#   curl -fsSL https://raw.githubusercontent.com/coden607/ocs/main/01-vps-key.sh | bash
set -uo pipefail
trap 'echo; echo "[x] stopped"; exit 130' INT
say(){ echo "[*] $*"; }
ok(){ echo "[+] $*"; }
warn(){ echo "[!] $*"; }
die(){ echo "[x] $*"; exit 1; }
REPO="${VPS_REPO:-coden607/ocs}"
KEY="/root/.github_actions"
say "=== VPS key for GitHub Actions ==="
[ "$(id -u)" = 0 ] || die "run as root"
command -v ssh-keygen >/dev/null || die "ssh-keygen missing"
if [ ! -s "$KEY" ] || [ ! -s "$KEY.pub" ]; then
  say "generating ed25519 key $KEY"
  rm -f "$KEY" "$KEY.pub"
  ssh-keygen -t ed25519 -f "$KEY" -N "" -q || die "ssh-keygen failed"
else
  ok "key already exists: $KEY"
fi
chmod 600 "$KEY"
chmod 644 "$KEY.pub"
mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys
if grep -qxF "$(cat "$KEY.pub")" /root/.ssh/authorized_keys; then
  ok "public key already in authorized_keys"
else
  cat "$KEY.pub" >> /root/.ssh/authorized_keys
  ok "public key appended to authorized_keys"
fi
chmod 600 /root/.ssh/authorized_keys
say "sshd checks"
if command -v sshd >/dev/null 2>&1; then
  sshd -T 2>/dev/null | grep -Ei 'permitrootlogin|pubkeyauthentication' || warn "could not read sshd -T"
fi
grep -c . /root/.ssh/authorized_keys | awk '{print "[+] authorized_keys lines: "$1}'
stat -c '%a %U:%G %n' /root/.ssh /root/.ssh/authorized_keys
if ! command -v gh >/dev/null 2>&1; then
  say "installing gh"
  apt-get update -qq && apt-get install -y -qq gh || die "could not install gh"
fi
if ! gh auth status -h github.com >/dev/null 2>&1; then
  die "gh is not logged in on this VPS. Run: gh auth login   then re-run this script"
fi
say "writing private key to Actions secret VPS_SSH_KEY on $REPO"
gh secret set VPS_SSH_KEY < "$KEY" -R "$REPO" || die "gh secret set failed"
ok "VPS_SSH_KEY set from $KEY"
echo
ok "DONE. Re-run Actions workflow setup-vpsbot on main."
echo "[+] fingerprint: $(ssh-keygen -lf "$KEY")"
