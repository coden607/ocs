import hmac, html, os, re, subprocess, tempfile, threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from telegram.ext import Updater, MessageHandler, Filters

TOKEN = os.environ["VPSBOT_TOKEN"]
ALLOWED = set(filter(None, os.environ.get("VPSBOT_CHATS", "").split(",")))
BUFFERS = {}
LAST = {"out": "(nothing run yet)"}
READ_TOKEN = os.environ.get("VPSBOT_READ_TOKEN", "")

class Last(BaseHTTPRequestHandler):
    # Read-only: returns the last run's output to the phone's "VPS copy" shortcut.
    def do_GET(self):
        auth = self.headers.get("Authorization", "")
        if self.path != "/last" or not hmac.compare_digest(auth, "Bearer " + READ_TOKEN):
            self.send_response(404); self.end_headers(); return
        body = LAST["out"].encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers(); self.wfile.write(body)
    def log_message(self, *a):
        pass

def serve_last():
    host = os.environ.get("VPSBOT_HTTP_BIND", "127.0.0.1")
    port = int(os.environ.get("VPSBOT_HTTP_PORT", "8765"))
    HTTPServer((host, port), Last).serve_forever()

def reply_chunks(update, text, n=3500):
    # Monospace <pre> blocks: tap one in Telegram to copy it, then paste into the LLM.
    for i in range(0, len(text), n):
        update.message.reply_text("<pre>%s</pre>" % html.escape(text[i:i+n]), parse_mode="HTML")

def run_file(update, path):
    update.message.reply_text("[*] running on vps...")
    os.chmod(path, 0o700)
    try:
        p = subprocess.run(["bash", path], capture_output=True, text=True, timeout=3600)
        out = (p.stdout + "\n" + p.stderr).strip() or "(no output)"
        LAST["out"] = f"exit={p.returncode}\n{out}"
        reply_chunks(update, f"exit={p.returncode}\n--- output ---\n{out}")
    except subprocess.TimeoutExpired:
        update.message.reply_text("timed out after 1h")

def handle_doc(update, context):
    cid = str(update.effective_chat.id)
    if cid not in ALLOWED:
        return
    doc = update.message.document
    if not doc:
        return
    tmp = tempfile.NamedTemporaryFile("wb", suffix=".sh", delete=False)
    tmp.close()
    doc.get_file().download(custom_path=tmp.name)
    run_file(update, tmp.name)
    os.unlink(tmp.name)

def handle_text(update, context):
    cid = str(update.effective_chat.id)
    if cid not in ALLOWED:
        return
    text = update.message.text or ""
    low = text.strip()
    if low == "CLEAR":
        BUFFERS.pop(cid, None); update.message.reply_text("buffer cleared"); return
    if low == "GO":
        parts = BUFFERS.pop(cid, [])
        if not parts:
            update.message.reply_text("buffer empty"); return
        blocks = re.findall(r"```(?:bash|sh|shell)?\n(.*?)```", "\n".join(parts), re.S)
        script = "\n".join(blocks) if blocks else "\n".join(parts)
        tmp = tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False)
        tmp.write(script); tmp.close()
        run_file(update, tmp.name); os.unlink(tmp.name); return
    blocks = re.findall(r"```(?:bash|sh|shell)?\n(.*?)```", text, re.S)
    outside = re.sub(r"```(?:bash|sh|shell)?\n.*?```", "", text, flags=re.S).strip()
    if len(blocks) == 1 and not outside:
        tmp = tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False)
        tmp.write(blocks[0]); tmp.close()
        run_file(update, tmp.name); os.unlink(tmp.name); return
    if text.startswith("#!"):
        tmp = tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False)
        tmp.write(text); tmp.close()
        run_file(update, tmp.name); os.unlink(tmp.name); return
    BUFFERS.setdefault(cid, []).append(text)
    total = sum(len(m) for m in BUFFERS[cid])
    update.message.reply_text(f"buffered ({total} chars). Send GO to run, CLEAR to reset.")

if READ_TOKEN:
    threading.Thread(target=serve_last, daemon=True).start()
u = Updater(TOKEN)
u.dispatcher.add_handler(MessageHandler(Filters.document, handle_doc))
u.dispatcher.add_handler(MessageHandler(Filters.text & ~Filters.command, handle_text))
u.start_polling()
u.idle()
