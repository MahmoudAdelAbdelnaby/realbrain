"""Start the backend: on this PC through a Cloudflare quick tunnel, or on the Oracle VM behind Caddy.

    .venv\\Scripts\\python -m scripts.serve            # tunnel + backend
    .venv\\Scripts\\python -m scripts.serve --lan      # home Wi-Fi only, no tunnel
    python -m scripts.serve --lan --publish           # the VM (PUBLIC_URL = its fixed address)

--publish writes the address to Firestore (config/backend) and every phone switches to it by
itself. Without it the phones stay where they are, so a PC run for development doesn't pull them
off the VM. Add --publish on the PC to take them over (the quick tunnel's address changes on every
start); restarting the VM's container moves them back.
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
    p.add_argument("--publish", action="store_true", help="point every phone at this backend")
    a = p.parse_args()
    load_env()

    tunnel = None
    if a.lan:
        url = os.environ.get("PUBLIC_URL", f"http://127.0.0.1:{a.port}")
    else:
        tunnel, url = start_tunnel(a.port)
    os.environ["PUBLIC_URL"] = url  # before importing the app: upload URLs use it

    print(f"\n  Backend: {url}")
    if a.publish:
        from app import store

        store.doc_set("config/backend", {"url": url, "started_at": time.time()})
        print("  Published to Firestore config/backend; the app switches to it by itself.\n")
    else:
        print("  Not published (no --publish): phones stay on the backend in config/backend.\n")

    import uvicorn

    from app import recall

    # ponytail: an in-process daily loop fine for one backend; a scheduler if it ever runs as several.
    threading.Thread(target=recall.loop, daemon=True).start()

    try:
        uvicorn.run("app.main:app", host="0.0.0.0", port=a.port)
    finally:
        if tunnel:
            tunnel.terminate()
    return 0


if __name__ == "__main__":
    sys.path.insert(0, str(ROOT))
    sys.exit(main())
