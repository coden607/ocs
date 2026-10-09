# ocs — One-Click Setup

Five numbered shell scripts + a Telegram bot that turn a fresh VPS into a
phone-controlled runner. Triggered from the droplet console or an iPhone
(iSH) and, for the final install step, a GitHub Actions workflow.

## What's here

| Path | What it does |
|------|--------------|
| `01-vps-key.sh` | Run on the VPS as root. Generates an ed25519 keypair, installs the public key in `authorized_keys`, and stores the private key as the GitHub Actions secret `VPS_SSH_KEY` on this repo. |
| `02-telegram.sh` | Validates a BotFather token + chat ID, creates a Python venv at `/opt/vpsbot`, installs `vpsbot/bot.py` as a systemd service, and sends a "live" confirmation to Telegram. Non-interactive when `VPSBOT_TOKEN` / `VPSBOT_CHATS` are set. |
| `03-ish-setup.sh` | Interactive helper meant for iSH on iPhone: opens BotFather/userinfobot/GitHub/Vercel URLs, saves token + chat ID locally, and can push the full Telegram setup to the VPS over SSH. |
| `04-set-bot-secrets.sh` | Run on the VPS console. Prompts for the BotFather token and chat ID (input hidden), verifies them against the Telegram API, and stores `BOT_TOKEN` + `TG_CHAT_ID` as Actions secrets. |
| `05-shortcut.sh` | Walks through building an iOS Shortcut ("VPS run") that sends clipboard contents to the bot via `sendMessage`, plus optional Back Tap binding. Can generate and Telegram-deliver a ready-made `.shortcut` file. |
| `vpsbot/bot.py` | Telegram long-polling bot (python-telegram-bot 13.x). Accepts shell scripts as documents or `#!/bin/bash` text / fenced code blocks, executes them on the VPS (up to 1h timeout), and replies with exit code + output. Supports multi-message buffering (`GO` to run, `CLEAR` to reset). |
| `.github/workflows/setup-vpsbot.yml` | Manually-dispatched workflow that SSHes into the VPS (`134.122.113.44`) using `VPS_SSH_KEY` and runs `02-telegram.sh` with the `BOT_TOKEN` / `TG_CHAT_ID` secrets. |
| `07-backtap.sh` | Run on the VPS. One command, no prompts: builds the "VPS run" iPhone shortcut from the saved bot token/chat ID and sends the file plus tap-to-copy manual values to your Telegram chat. |
| `06-copyback.sh` | Run on the VPS (needs Tailscale on VPS + iPhone). Adds a token-protected, read-only `/last` endpoint bound to the Tailscale IP, and prints the steps for a "VPS copy" shortcut (Back Tap triple-tap) that puts the last output on the clipboard. |

## Setup order

1. On the VPS: `curl -fsSL https://raw.githubusercontent.com/coden607/ocs/main/01-vps-key.sh | bash`
2. On the VPS console: `curl -fsSL https://raw.githubusercontent.com/coden607/ocs/main/04-set-bot-secrets.sh | bash`
3. GitHub → Actions → **setup-vpsbot** → Run workflow (installs the bot)
4. Optional: `05-shortcut.sh` for the iPhone double-tap shortcut
5. Optional return tap: `06-copyback.sh` (double-tap sends, triple-tap copies the result)
6. Alternative path for iPhone-only: `03-ish-setup.sh` inside iSH

## Security notes

- The bot executes **any** script sent from the allowed chat ID(s) as root.
  Guard the Telegram account accordingly.
- Secrets live in GitHub Actions secrets and `/root/.vpsbot.env` (mode 600);
  nothing is committed to the repo.

## Agent policy

See `AGENTS.md`: use the canonical [coden607/skills](https://github.com/coden607/skills) library. `CLAUDE.md`, `GEMINI.md` and `.github/copilot-instructions.md` defer to it.
