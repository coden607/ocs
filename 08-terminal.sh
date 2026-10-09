#!/usr/bin/env bash
# Install terminal capture for the iPhone's read-only SSH shortcut.
set -Eeuo pipefail
umask 077
die() { printf '[x] %s\n' "$*" >&2; exit 1; }
trap 'printf "\n[x] Interrupted; rerun to finish.\n" >&2; exit 130' INT
trap 'printf "\n[x] Stopped; rerun to finish.\n" >&2; exit 143' TERM
case "${1:-}" in ''|--no-attach) ;; *) die 'Usage: bash 08-terminal.sh [--no-attach]' ;; esac
printf '[1/3] Checking tmux...\n'
if ! command -v tmux >/dev/null; then
  [ "$(id -u)" = 0 ] || die 'Run this as your VPS root user to install tmux.'
  command -v apt-get >/dev/null || die 'This installer supports Debian/Ubuntu; install tmux first elsewhere.'
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq tmux
fi
printf '[2/3] Installing capture helper...\n'
BIN="$HOME/.local/bin"
mkdir -p "$BIN"
TMP=$(mktemp "$BIN/.ocs.XXXXXX")
trap 'rm -f -- "$TMP"' EXIT
cat > "$TMP" <<'HELPER'
#!/usr/bin/env bash
set -Eeuo pipefail
# Dedicated socket avoids changing existing tmux sessions or configuration.
TMUX_BIN=$(command -v tmux) || { echo '[x] tmux missing' >&2; exit 1; }
case "${1:-help}" in
  shell)
    [ -z "${TMUX:-}" ] || { echo '[x] Detach from your current tmux session first (Ctrl-B, D).' >&2; exit 1; }
    exec "$TMUX_BIN" -L ocs-copy -f /dev/null new-session -A -s ocs-copy
    ;;
  last)
    "$TMUX_BIN" -L ocs-copy has-session -t '=ocs-copy' 2>/dev/null || {
      echo '[x] No capture session. Run ~/.local/bin/ocs shell on the VPS.' >&2; exit 1;
    }
    # Exact session target resolves its active window and pane. No escape colours.
    CAPTURE=$("$TMUX_BIN" -L ocs-copy capture-pane -p -J -S -300 -t '=ocs-copy:')
    printf '%s\n' "$CAPTURE" | tail -n 300 | awk '
      { sub(/[[:space:]]+$/, ""); lines[NR]=$0; if ($0 !~ /^[[:space:]]*$/) last=NR }
      END { for (i=1; i<=last; i++) print lines[i] }
    '
    ;;
  help|--help|-h)
    printf 'ocs shell  Open/resume the terminal captured by Back Tap\nocs last   Read its last 300 lines (no commands executed)\n'
    ;;
  *) echo '[x] Usage: ocs shell | last | help' >&2; exit 2 ;;
esac
HELPER
chmod 700 "$TMP"
if [ -e "$BIN/ocs" ] || [ -L "$BIN/ocs" ]; then
  cmp -s "$TMP" "$BIN/ocs" || die "$BIN/ocs already exists with different contents; left untouched."
  printf '[+] Already installed; existing helper preserved.\n'
else
  # Atomic no-clobber install, including simultaneous installer runs.
  ln "$TMP" "$BIN/ocs" || die 'Install conflict; existing helper left untouched.'
fi
printf '[3/3] Ready. iPhone shortcut: VPS to LLM\n'
cat <<'STEPS'
Actions in Shortcuts:
  1. Run Script over SSH: your VPS host, port 22, same VPS user.
     Script: ~/.local/bin/ocs last
     Authenticate with your SSH key or password inside Shortcuts.
  2. Copy to Clipboard: use the SSH action's Result variable.
  3. Open App: ChatGPT (or your preferred LLM).
Assign Settings > Accessibility > Touch > Back Tap > Triple Tap > VPS to LLM.
Use this terminal for commands. Triple-tap, then tap Paste in the LLM chat.
Ctrl-B then D detaches; ~/.local/bin/ocs shell reconnects.
STEPS
if [ "${1:-}" != --no-attach ] && ( : </dev/tty ) 2>/dev/null; then
  printf '[+] Opening your capture terminal...\n'
  "$BIN/ocs" shell </dev/tty >/dev/tty 2>/dev/tty
else
  printf '[+] Start capture: ~/.local/bin/ocs shell\n'
fi
