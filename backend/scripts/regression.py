"""P1-17: run the test set (test/fixtures/reels.md) through fetch + Extract and print accuracy.

    .venv\\Scripts\\python -m scripts.regression            # all rows
    .venv\\Scripts\\python -m scripts.regression --only 4   # one row

Server-side only (fallback chain: YouTube direct, TikWM, yt-dlp, caption); no Firestore writes,
no notifications. Exit code 1 below the 85% gate. Uses one Gemini call per reel.
"""

import argparse
import os
import re
import sys
import tempfile
import time
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIXTURE = ROOT.parent / "test" / "fixtures" / "reels.md"
GATE = 0.85


def load_env() -> None:
    env = ROOT / ".env"
    if env.exists():
        for line in env.read_text("utf-8").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())


def rows(text: str) -> list[dict]:
    """Table rows with a URL and an expected section."""
    out = []
    for line in text.splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) >= 5 and re.match(r"https?://", cells[2]):
            out.append(
                {"n": cells[0], "platform": cells[1].lower(), "url": cells[2], "expected": cells[4].lower()}
            )
    return out


def judge(expected: str, sections: list[tuple[str, float]], review_below: float = 0.6) -> bool:
    """Correct when the expected section is (joint) most confident and confident enough;
    `none` is correct when nothing clears the bar (it would go to review)."""
    confident = [s for s in sections if s[1] >= review_below]
    if expected == "none":
        return not confident
    top = max((c for _, c in confident), default=None)
    return top is not None and any(t == expected and c == top for t, c in confident)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--only", help="row number to run")
    a = p.parse_args()
    load_env()
    os.environ.setdefault("GEMINI_MIN_GAP_S", "15")
    from app.main import platform
    from app.pipeline.extract import extract
    from app.pipeline.fetch import fallback

    tests = [r for r in rows(FIXTURE.read_text("utf-8")) if not a.only or r["n"] == a.only]
    per = defaultdict(lambda: [0, 0])
    print(f"{'#':>2}  {'expected':<10} {'got':<28} {'path':<8} {'s':>5}  ok")
    for r in tests:
        save = {"source_url": r["url"], "platform": platform(r["url"]), "save_id": f"regression-{r['n']}"}
        started = time.monotonic()
        with tempfile.TemporaryDirectory() as tmp:
            got = fallback(save, Path(tmp) / "video.mp4")
            if got.used == "none":
                sections, path = [], "none"
            else:
                result = extract(
                    got.path, got.caption, {"platform": save["platform"], "url": r["url"]}, video_uri=got.uri
                )
                sections, path = [(s.type, s.confidence) for s in result.sections], got.used
        ok = judge(r["expected"], sections)
        per[r["expected"]][0] += ok
        per[r["expected"]][1] += 1
        shown = ", ".join(f"{t} {c:.2f}" for t, c in sections) or "none"
        print(
            f"{r['n']:>2}  {r['expected']:<10} {shown:<28} {path:<8} {time.monotonic() - started:5.0f}  {'yes' if ok else 'NO'}"
        )
    total = sum(c for c, _ in per.values()), sum(n for _, n in per.values())
    print()
    for section, (c, n) in sorted(per.items()):
        print(f"  {section:<10} {c}/{n}")
    rate = total[0] / total[1] if total[1] else 0
    print(f"  overall    {total[0]}/{total[1]} = {rate:.0%} (gate {GATE:.0%})")
    return 0 if rate >= GATE else 1


if __name__ == "__main__":
    sys.path.insert(0, str(ROOT))
    sys.exit(main())
