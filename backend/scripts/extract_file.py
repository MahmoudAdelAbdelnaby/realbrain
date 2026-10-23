"""Run one real reel through the Extract call and print the JSON.

    python -m scripts.extract_file path/to/reel.mp4 --caption "..." [--platform tiktok]
    python -m scripts.extract_file --url https://youtube.com/shorts/...   (Gemini reads YouTube itself)

Needs GEMINI_API_KEY in the environment or backend/.env. Also cuts the key frame next to the video.
"""

import argparse
import os
import sys
import time
from pathlib import Path


def load_env() -> None:
    env = Path(__file__).resolve().parent.parent / ".env"
    if env.exists():
        for line in env.read_text("utf-8").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())


def main() -> int:
    load_env()
    from app.pipeline.extract import MODEL, extract
    from app.pipeline.frames import key_frame
    from app.schemas import needs_review

    p = argparse.ArgumentParser()
    p.add_argument("video", nargs="?", type=Path)
    p.add_argument("--url")
    p.add_argument("--caption")
    p.add_argument("--platform")
    a = p.parse_args()
    if not a.video and not a.url:
        p.error("give a video file or --url")

    started = time.monotonic()
    result = extract(a.video, a.caption, {"platform": a.platform, "url": a.url}, video_uri=a.url)
    took = time.monotonic() - started
    print(result.model_dump_json(indent=2))
    sections = ", ".join(f"{s.type} {s.confidence:.2f}" for s in result.sections) or "none"
    print(
        f"\nmodel={MODEL} latency={took:.1f}s sections=[{sections}] needs_review={needs_review(result)}",
        file=sys.stderr,
    )
    if a.video and result.key_frame_t is not None:
        out = key_frame(a.video, result.key_frame_t, a.video.with_suffix(".frame.jpg"))
        print(f"key frame: {out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
