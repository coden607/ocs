#!/usr/bin/env bash
# 05-shortcut.sh — one step at a time. Run in the droplet console.
#   curl -fsSL https://raw.githubusercontent.com/coden607/ocs/main/05-shortcut.sh | bash
set -uo pipefail
TTY=/dev/tty
[ -r "$TTY" ] || { echo "[x] need the droplet console"; exit 1; }
pause(){ printf "\n[enter] %s" "$1" >"$TTY"; read -r _ <"$TTY"; echo >"$TTY"; }
say(){ echo "[*] $*"; }
ok(){ echo "[+] $*"; }
echo
say "VPS run shortcut. One step. Press Enter after you finish each one."
pause "ready"
say "1. Open the Shortcuts app. Tap the plus button."
pause "done"
say "2. Name the shortcut: VPS run"
pause "done"
say "3. Add action: Get Clipboard"
pause "done"
say "4. Add action: Text"
say "   Type this, then Return:"
echo "#!/bin/bash"
say "   Tap the Clipboard variable so it is on the next line."
pause "done"
say "5. Add action: Get Contents of URL"
say "   Method: POST"
say "   URL is https://api.telegram.org/bot  then your BotFather token  then /sendMessage"
say "   Do not paste the token into chat. It is the key already on this droplet."
pause "URL set"
say "6. Request Body: Form"
say "   Add field chat_id = the number from @userinfobot"
say "   Add field text = the Text variable from step 4"
pause "form set"
say "7. Tap Done."
pause "shortcut saved"
say "8. Settings > Accessibility > Touch > Back Tap > Double Tap > VPS run"
pause "back tap set"
ok "Copy a script. Double-tap the back of the phone."
say "Bot should reply: [*] running on vps..."
echo
printf "[?] also send a ready-made VPS-run.shortcut file to Telegram? [y/N] " >"$TTY"
read -r YN <"$TTY" || YN=n
case "$YN" in
  y|Y)
    [ -f /root/.vpsbot.env ] || { echo "[x] no /root/.vpsbot.env"; exit 1; }
    python3 - << 'PY'
import json, os, plistlib, uuid, urllib.request
from pathlib import Path
env = {}
for line in Path("/root/.vpsbot.env").read_text().splitlines():
    if "=" in line:
        k, v = line.split("=", 1)
        env[k] = v
token, chat = env["TOKEN"], env["CHAT_ID"]
clip, text = str(uuid.uuid4()), str(uuid.uuid4())
fffc = "\ufffc"
body = {
    "WFWorkflowMinimumClientVersionString": "900",
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowClientVersion": "2700.0.4",
    "WFWorkflowIcon": {"WFWorkflowIconStartColor": 2071128575, "WFWorkflowIconGlyphNumber": 59511},
    "WFWorkflowTypes": [],
    "WFWorkflowImportQuestions": [],
    "WFWorkflowInputContentItemClasses": ["WFStringContentItem"],
    "WFWorkflowActions": [
        {"WFWorkflowActionIdentifier": "is.workflow.actions.getclipboard", "WFWorkflowActionParameters": {"UUID": clip}},
        {"WFWorkflowActionIdentifier": "is.workflow.actions.gettext", "WFWorkflowActionParameters": {"UUID": text, "WFTextActionText": {"Value": {"string": "#!/bin/bash\n" + fffc, "attachmentsByRange": {"{12, 1}": {"Type": "ActionOutput", "OutputName": "Clipboard", "OutputUUID": clip}}}, "WFSerializationType": "WFTextTokenString"}}},
        {"WFWorkflowActionIdentifier": "is.workflow.actions.downloadurl", "WFWorkflowActionParameters": {"WFHTTPMethod": "POST", "WFURL": "https://api.telegram.org/bot%s/sendMessage" % token, "WFHTTPBodyType": "Form", "WFFormValues": {"Value": {"WFDictionaryFieldValueItems": [
            {"WFItemType": 0, "WFKey": {"Value": {"string": "chat_id"}, "WFSerializationType": "WFTextTokenString"}, "WFValue": {"Value": {"string": chat}, "WFSerializationType": "WFTextTokenString"}},
            {"WFItemType": 0, "WFKey": {"Value": {"string": "text"}, "WFSerializationType": "WFTextTokenString"}, "WFValue": {"Value": {"string": fffc, "attachmentsByRange": {"{0, 1}": {"Type": "ActionOutput", "OutputName": "Text", "OutputUUID": text}}}, "WFSerializationType": "WFTextTokenString"}},
        ]}, "WFSerializationType": "WFDictionaryFieldValue"}}},
    ],
}
path = "/tmp/VPS-run.shortcut"
with open(path, "wb") as f:
    plistlib.dump(body, f, fmt=plistlib.FMT_BINARY)
boundary = "----vps" + uuid.uuid4().hex
data = Path(path).read_bytes()
parts = []
def add(name, value, filename=None):
    parts.append(("--%s\r\n" % boundary).encode())
    if filename:
        parts.append(("Content-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\nContent-Type: application/octet-stream\r\n\r\n" % (name, filename)).encode())
        parts.append(value)
        parts.append(b"\r\n")
    else:
        parts.append(("Content-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % (name, value)).encode())
add("chat_id", chat)
add("caption", "Open VPS-run.shortcut and tap Add Shortcut.")
add("document", data, "VPS-run.shortcut")
parts.append(("--%s--\r\n" % boundary).encode())
req = urllib.request.Request("https://api.telegram.org/bot%s/sendDocument" % token, data=b"".join(parts), headers={"Content-Type": "multipart/form-data; boundary=%s" % boundary})
with urllib.request.urlopen(req, timeout=30) as r:
    d = json.loads(r.read().decode())
print("telegram", d.get("ok"))
PY
    ok "file sent to Telegram"
    ;;
  *) ok "manual shortcut only" ;;
esac
