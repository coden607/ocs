# VPS terminal → LLM with Back Tap

Run `08-terminal.sh` on the VPS as the same user your terminal and iPhone SSH
shortcut use. It installs tmux if needed on Debian/Ubuntu and adds
`~/.local/bin/ocs`. It leaves a different existing `ocs` file untouched.
It does not change your Telegram bot, SSH settings, shell startup files, or
existing tmux server. Run it again safely to resume setup.

The installer opens a dedicated capture terminal when a terminal is available.
Otherwise start it with:

```bash
~/.local/bin/ocs shell
```

Run your normal commands there. A separate SSH connection can read its active
pane while a command runs, and after you detach with **Ctrl-B, D**. Reconnect
with the same command. Exiting the last shell ends the session and its history.
Previously printed output outside this session cannot be retrieved.

## One-time iPhone setup

In **Shortcuts**, create **VPS to LLM** with these actions, in order:

1. **Run Script over SSH**. Host: your current VPS IP or hostname. Port: 22.
   User: the same account used for installation. Configure your existing SSH
   key or password locally in Shortcuts. Script:

   ```bash
   ~/.local/bin/ocs last
   ```

2. **Copy to Clipboard**, with the **Result** variable from the SSH action.
3. **Open App**, choosing ChatGPT or another installed LLM app.

Run the shortcut once and allow the requested connection/clipboard permissions.
Assign **Settings → Accessibility → Touch → Back Tap → Triple Tap → VPS to LLM**.

After that: run commands in the capture terminal, triple-tap the back of your
iPhone, and paste in your LLM chat. The shortcut copies the active pane's most
recent 300 lines without colour escapes and opens the selected app. It does
not submit the output. Generic Shortcuts actions do not paste into arbitrary
apps' chat fields; a manual Paste tap remains with this workflow.

This uses your existing SSH connection. No Telegram token, new public endpoint,
Tailscale setup, or LLM API key is needed. This session can contain credentials
printed by commands; review before sending to the LLM.

## Check or troubleshoot

```bash
~/.local/bin/ocs last
```

- **No capture session**: start `ocs shell` and run a command there.
- **SSH connection fails**: confirm the host, username and authentication in
  Shortcuts match the working terminal connection.
- **Wrong output**: the shortcut reads the active window/pane in the dedicated
  `ocs-copy` session, so switch to the pane you want before tapping.
- **Installer says file exists**: it refused to replace an unrelated helper.
- **Empty output**: type a command in the capture terminal and retry.
- **Can't use /dev/tty**: run `~/.local/bin/ocs shell` directly from your
  interactive prompt. The installer must inherit the actual terminal, not
  reopen `/dev/tty`; piped/noninteractive installs print the reconnect command.

Phone execution and Back Tap require verification on the actual iPhone.
