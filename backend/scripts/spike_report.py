"""P0-07: print the spike report table (one row per save) as Markdown, to paste into docs/BUILD_PLAN.md.

    python -m scripts.spike_report            # local saves (backend/data)
    python -m scripts.spike_report --cloud    # Firestore, needs gcloud auth application-default login

Fill the "Correct?" column by hand after checking each result against the reel.
"""

import argparse
import json
import os
import sys
from pathlib import Path


def local_saves() -> list[dict]:
    from app.store import DATA

    return [json.loads(p.read_text("utf-8")) for p in (DATA / "saves").glob("*.json")]


def cloud_saves(project: str) -> list[dict]:
    from google.cloud import firestore

    db = firestore.Client(project=project)
    saves = []
    for doc in db.collection_group("saves").stream():
        save = doc.to_dict()
        save["items"] = [i.to_dict() for i in doc.reference.collection("items").stream()]
        saves.append(save)
    return saves


def row(n: int, s: dict) -> str:
    items = sorted(s.get("items") or [], key=lambda i: -i.get("confidence", 0))
    sections = ", ".join(f"{i['section']} {i['confidence']:.2f}" for i in items) or "none"
    latency = f"{s['extract_ms'] / 1000:.1f}" if s.get("extract_ms") else ""
    url = s.get("source_url", "")
    return f"| {n} | {s.get('platform', '')} | {url} | {s.get('fetch_path', '')} | {latency} | {sections} | {s.get('status', '')} |  |"


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--cloud", action="store_true")
    p.add_argument("--project", default=os.environ.get("GOOGLE_CLOUD_PROJECT", "reelbrain-dev"))
    a = p.parse_args()
    saves = sorted(cloud_saves(a.project) if a.cloud else local_saves(), key=lambda s: s.get("created_at", 0))
    print("| # | Platform | Reel | Download path | Gemini s | Sections detected | Status | Correct? |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for n, s in enumerate(saves, 1):
        print(row(n, s))
    done = [s for s in saves if s.get("status") in ("ready", "needs_review", "partial")]
    phone = sum(s.get("fetch_path") == "phone" for s in done)
    print(f"\n{len(done)}/{len(saves)} processed, {phone} via the phone's own download.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
    sys.exit(main())
