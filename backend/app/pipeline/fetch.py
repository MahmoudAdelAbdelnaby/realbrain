"""Fallback chain when the phone couldn't upload the video (P0-06).

YouTube: Gemini reads the URL itself. Otherwise: cloud mirror -> yt-dlp from here -> caption only.
Datacenter IPs are often blocked by TikTok/Instagram, which is why the phone path comes first.
"""

import logging
import time
from dataclasses import dataclass, field
from pathlib import Path

import httpx

log = logging.getLogger("reelbrain.fetch")
MAX_BYTES = 200 * 1024 * 1024
UA = {"User-Agent": "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130 Mobile Safari/537.36"}


@dataclass
class Fetched:
    path: Path | None = None  # local video
    uri: str | None = None  # URL Gemini reads itself
    caption: str | None = None
    creator: str | None = None
    used: str = "none"
    steps: list[dict] = field(default_factory=list)


class Skip(Exception):
    """This step doesn't apply to the URL (not a failure worth retrying)."""


def youtube_direct(save: dict, dest: Path) -> Fetched:
    if save.get("platform") != "youtube":
        raise Skip("not youtube")
    return Fetched(uri=save["source_url"])


def tikwm_mirror(save: dict, dest: Path) -> Fetched:
    """TikWM public API (third party, may vanish any day; see PRD option B)."""
    if save.get("platform") != "tiktok":
        raise Skip("no mirror for this platform")
    r = httpx.get("https://www.tikwm.com/api/", params={"url": save["source_url"], "hd": 0}, timeout=20)
    r.raise_for_status()
    play, caption, creator = parse_tikwm(r.json())
    _download(play, dest)
    return Fetched(path=dest, caption=caption, creator=creator)


def parse_tikwm(body: dict) -> tuple[str, str | None, str | None]:
    if body.get("code") != 0 or not (body.get("data") or {}).get("play"):
        raise RuntimeError(f"tikwm: {body.get('msg') or 'no video'}")
    data = body["data"]
    return data["play"], data.get("title") or None, (data.get("author") or {}).get("nickname")


def ytdlp_server(save: dict, dest: Path) -> Fetched:
    import yt_dlp

    opts = {
        "format": "b[height<=720]/b",
        "outtmpl": str(dest.with_suffix(".%(ext)s")),
        "noplaylist": True,
        "quiet": True,
        "socket_timeout": 20,
        "max_filesize": MAX_BYTES,
    }
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(save["source_url"], download=True)
        got = Path(ydl.prepare_filename(info))
    if not got.exists():
        raise RuntimeError("yt-dlp wrote no file")
    got.replace(dest)
    return Fetched(
        path=dest, caption=info.get("description") or info.get("title"), creator=info.get("uploader")
    )


def oembed_caption(save: dict, dest: Path) -> Fetched:
    """Caption-only: whatever text we can get without the video (PRD option D)."""
    caption, creator = save.get("caption"), save.get("creator")
    if not caption and save.get("platform") == "tiktok":
        r = httpx.get(
            "https://www.tiktok.com/oembed", params={"url": save["source_url"]}, headers=UA, timeout=15
        )
        if r.status_code == 200:
            caption, creator = r.json().get("title") or None, r.json().get("author_name") or creator
    if not caption:
        raise RuntimeError("no caption available")
    return Fetched(caption=caption, creator=creator)


CHAIN = [
    ("youtube", youtube_direct),
    ("mirror", tikwm_mirror),
    ("yt-dlp", ytdlp_server),
    ("caption", oembed_caption),
]


def fallback(save: dict, dest: Path) -> Fetched:
    """First step that works wins; every step's outcome is recorded for the spike report."""
    steps = []
    for name, step in CHAIN:
        started = time.monotonic()
        try:
            got = step(save, dest)
        except Skip as e:
            steps.append({"step": name, "ok": False, "skipped": True, "detail": str(e)})
            continue
        except Exception as e:  # noqa: BLE001 - any failure moves on to the next step
            steps.append({"step": name, "ok": False, "ms": _ms(started), "detail": str(e)[:200]})
            log.info("save=%s fetch %s failed: %s", save.get("save_id"), name, e)
            continue
        steps.append({"step": name, "ok": True, "ms": _ms(started)})
        log.info("save=%s fetched via %s", save.get("save_id"), name)
        got.used, got.steps = name, steps
        got.caption = got.caption or save.get("caption")
        return got
    return Fetched(steps=steps)


def _download(url: str, dest: Path) -> None:
    with httpx.stream("GET", url, headers=UA, timeout=60, follow_redirects=True) as r:
        r.raise_for_status()
        size = 0
        with dest.open("wb") as f:
            for chunk in r.iter_bytes():
                size += len(chunk)
                if size > MAX_BYTES:
                    raise RuntimeError("video too large")
                f.write(chunk)


def _ms(started: float) -> int:
    return int((time.monotonic() - started) * 1000)
