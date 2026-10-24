"""Start the backend on this PC, reachable from anywhere through a Cloudflare quick tunnel.

    .venv\\Scripts\\python -m scripts.serve            # tunnel + backend
    .venv\\Scripts\\python -m scripts.serve --lan      # home Wi-Fi only, no tunnel

The quick tunnel's https://<random>.trycloudflare.com address changes on every start, so it is
published to Firestore (config/backend) and the app picks it up by itself. Free, no account.
ponytail: quick tunnel = new address per start and no uptime promise; a named tunnel (free
Cloudflare account + a domain) or Cloud Run gives a fixed one.
"""

import argparse
import os
import re
import subprocess
import sys
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# The tunnel line, not Cloudflare's own API host (which appears in errors when a request fails).
URL = re.compile(r"https://(?!api\.)[a-z0-9-]+\.trycloudflare\.com")


def load_env() -> None:
    env = ROOT / ".env"
    if env.exists():
        for line in env.read_text("utf-8").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())


def start_tunnel(port: int) -> tuple[subprocess.Popen, str]:
    proc = subprocess.Popen(
        ["cloudflared", "tunnel", "--no-autoupdate", "--url", f"http://localhost:{port}"],
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    found: list[str] = []

    def read() -> None:
        for line in proc.stderr:
            if not found and (m := URL.search(line)):
                found.append(m.group(0))
            if "ERR" in line:
                print("cloudflared:", line.rstrip(), file=sys.stderr)

    threading.Thread(target=read, daemon=True).start()
    deadline = time.time() + 60
    while not found and time.time() < deadline and proc.poll() is None:
        time.sleep(0.2)
    if not found:
        proc.terminate()
        raise SystemExit("cloudflared did not print a tunnel address within 60 s")
    return proc, found[0]


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--lan", action="store_true", help="no tunnel; phone must be on the same Wi-Fi")
    p.add_argument("--port", type=int, default=8000)
    a = p.parse_args()
    load_env()

    tunnel = None
    if a.lan:
        url = os.environ.get("PUBLIC_URL", f"http://127.0.0.1:{a.port}")
    else:
        tunnel, url = start_tunnel(a.port)
    os.environ["PUBLIC_URL"] = url  # before importing the app: upload URLs use it

    from app import store

    store.doc_set("config/backend", {"url": url, "started_at": time.time()})
    print(f"\n  Backend: {url}\n  Published to Firestore config/backend; the app switches to it by itself.\n")

    import uvicorn

    try:
        uvicorn.run("app.main:app", host="0.0.0.0", port=a.port)
    finally:
        if tunnel:
            tunnel.terminate()
    return 0


if __name__ == "__main__":
    sys.path.insert(0, str(ROOT))
    sys.exit(main())
