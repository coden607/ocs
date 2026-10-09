#!/usr/bin/env bash
# 07-backtap.sh - one command: builds the iPhone shortcut and sends it to your Telegram.
#   curl -fsSL https://raw.githubusercontent.com/coden607/ocs/main/07-backtap.sh | bash
# Reads /root/.vpsbot.env (TOKEN, CHAT_ID). No prompts, no pasting the token.
set -uo pipefail
E=/root/.vpsbot.env
[ -f "$E" ] || { echo "[x] $E missing. Run 02-telegram.sh first."; exit 1; }
command -v python3 >/dev/null || { apt-get update -qq && apt-get install -y -qq python3; }
echo "[*] building shortcut and sending to Telegram..."
python3 - "$E" <<'PY'
import json, plistlib, sys, uuid, urllib.request, urllib.parse
from pathlib import Path
env = {}
for line in Path(sys.argv[1]).read_text().splitlines():
    if "=" in line:
        k, v = line.split("=", 1); env[k] = v
token, chat = env["TOKEN"], env["CHAT_ID"]
api = "https://api.telegram.org/bot%s/" % token
url = api + "sendMessage"
clip, text = str(uuid.uuid4()), str(uuid.uuid4())
F = "￼"
body = {
 "WFWorkflowMinimumClientVersionString": "900", "WFWorkflowMinimumClientVersion": 900,
 "WFWorkflowClientVersion": "2700.0.4",
 "WFWorkflowIcon": {"WFWorkflowIconStartColor": 2071128575, "WFWorkflowIconGlyphNumber": 59511},
 "WFWorkflowTypes": [], "WFWorkflowImportQuestions": [],
 "WFWorkflowInputContentItemClasses": ["WFStringContentItem"],
 "WFWorkflowActions": [
  {"WFWorkflowActionIdentifier": "is.workflow.actions.getclipboard", "WFWorkflowActionParameters": {"UUID": clip}},
  {"WFWorkflowActionIdentifier": "is.workflow.actions.gettext", "WFWorkflowActionParameters": {"UUID": text, "WFTextActionText": {"Value": {"string": "#!/bin/bash\n" + F, "attachmentsByRange": {"{12, 1}": {"Type": "ActionOutput", "OutputName": "Clipboard", "OutputUUID": clip}}}, "WFSerializationType": "WFTextTokenString"}}},
  {"WFWorkflowActionIdentifier": "is.workflow.actions.downloadurl", "WFWorkflowActionParameters": {"WFHTTPMethod": "POST", "WFURL": url, "WFHTTPBodyType": "Form", "WFFormValues": {"Value": {"WFDictionaryFieldValueItems": [
   {"WFItemType": 0, "WFKey": {"Value": {"string": "chat_id"}, "WFSerializationType": "WFTextTokenString"}, "WFValue": {"Value": {"string": chat}, "WFSerializationType": "WFTextTokenString"}},
   {"WFItemType": 0, "WFKey": {"Value": {"string": "text"}, "WFSerializationType": "WFTextTokenString"}, "WFValue": {"Value": {"string": F, "attachmentsByRange": {"{0, 1}": {"Type": "ActionOutput", "OutputName": "Text", "OutputUUID": text}}}, "WFSerializationType": "WFTextTokenString"}},
  ]}, "WFSerializationType": "WFDictionaryFieldValue"}}},
 ],
}
data = plistlib.dumps(body, fmt=plistlib.FMT_BINARY)

def post(method, fields, file=None):
    b = "----vps" + uuid.uuid4().hex
    parts = []
    for k, v in fields.items():
        parts.append(("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % (b, k, v)).encode())
    if file:
        parts.append(("--%s\r\nContent-Disposition: form-data; name=\"document\"; filename=\"%s\"\r\nContent-Type: application/octet-stream\r\n\r\n" % (b, file[0])).encode())
        parts.append(file[1]); parts.append(b"\r\n")
    parts.append(("--%s--\r\n" % b).encode())
    req = urllib.request.Request(api + method, data=b"".join(parts), headers={"Content-Type": "multipart/form-data; boundary=" + b})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode()).get("ok")

def pre(s):
    return "<pre>%s</pre>" % s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

ok1 = post("sendDocument", {"chat_id": chat, "caption": "1) Tap this file, then Share > Shortcuts > Add Shortcut."}, ("VPS-run.shortcut", data))
steps = (
 "If the file will not import, build it by hand (Shortcuts > +). Tap each box below to copy it.\n\n"
 "Actions, in order:\n"
 "1. Get Clipboard\n"
 "2. Text: line 1 is #!/bin/bash, line 2 is the Clipboard variable\n"
 "3. Get Contents of URL: Method POST, Request Body Form, URL = box A\n"
 "4. Form field Text: chat_id = box B\n"
 "5. Form field Text: text = the Text variable from step 2\n"
 "Name it: VPS run\n\n"
 "Then: Settings > Accessibility > Touch > Back Tap > Double Tap > VPS run"
)
ok2 = post("sendMessage", {"chat_id": chat, "text": steps + "\n\nBox A (URL):" , })
ok3 = post("sendMessage", {"chat_id": chat, "parse_mode": "HTML", "text": pre(url)})
ok4 = post("sendMessage", {"chat_id": chat, "text": "Box B (chat_id):"})
ok5 = post("sendMessage", {"chat_id": chat, "parse_mode": "HTML", "text": pre(chat)})
print("[%s] file  [%s] recipe  [%s] url  [%s] chat id" % tuple("+" if x else "x" for x in (ok1, ok2, ok3, ok5)))
sys.exit(0 if all((ok1, ok2, ok3, ok4, ok5)) else 1)
PY
rc=$?
if [ $rc -eq 0 ]; then
  echo "[+] Open Telegram: file + copy boxes are in your bot chat."
  echo "[*] Last manual step (iOS has no API for it):"
  echo "    Settings > Accessibility > Touch > Back Tap > Double Tap > VPS run"
else
  echo "[x] Telegram send failed. Check: systemctl status vpsbot ; cat $E"
fi
exit $rc
