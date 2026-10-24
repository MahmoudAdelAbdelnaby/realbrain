"""Call 1, Extract: one Gemini call that watches the video and fills the AI contract."""

import logging
import os
import threading
import time
from functools import cache
from pathlib import Path

from app.schemas import ExtractResult, gemini_schema

log = logging.getLogger("reelbrain.extract")

# Free tier (AI Studio, 24 Oct 2026): each Flash model has its own 20 requests/day; 3.5 and 3.1 Flash-Lite 500/day each.
# Busy or out of quota -> the next model, so one save never burns a retry on the same overloaded model.
# 3.6 first: 3.8 answered in 200 s and 503'd repeatedly on the spike day; 3.6 in 3 s.
MODELS = os.environ.get(
    "GEMINI_MODELS", "gemini-3.6-flash,gemini-3.8-flash,gemini-3.5-flash-lite,gemini-3.1-flash-lite"
).split(",")
MODEL = MODELS[0]
TRANSIENT = (408, 429, 500, 502, 503, 504)
# Free tier allows 5 requests/minute per model: space Gemini calls so a burst of shares queues
# here instead of tripping 429s and falling down to Flash-Lite. Per process; the Cloud Tasks
# queue (infra/deploy.ps1) also dispatches one save at a time.
MIN_GAP_S = float(os.environ.get("GEMINI_MIN_GAP_S", "15"))
_pace_lock = threading.Lock()
_last_call = 0.0
PROMPT = (Path(__file__).resolve().parent.parent / "prompts" / "extract.md").read_text("utf-8")


def keys() -> list[str]:
    """GEMINI_API_KEYS (comma-separated, tried in order), else GEMINI_API_KEY.
    One key per Google account: several projects on one account to stack free quota breaks the API terms."""
    raw = os.environ.get("GEMINI_API_KEYS") or os.environ.get("GEMINI_API_KEY") or ""
    return [k.strip() for k in raw.split(",") if k.strip()]


def _pace() -> None:
    """Blocks until MIN_GAP_S has passed since the previous Gemini call; callers queue in order."""
    global _last_call
    with _pace_lock:
        wait = _last_call + MIN_GAP_S - time.monotonic()
        if wait > 0:
            log.info("pacing Gemini: waiting %.0fs", wait)
            time.sleep(wait)
        _last_call = time.monotonic()


class Transient(Exception):
    """Worth retrying later (quota, overload, timeouts): the job is retried, not failed."""


@cache
def client(key: str):
    from google import genai

    return genai.Client(api_key=key)


SECTION_NAMES = {
    "fact_check": "Fact Check",
    "tools": "Dev and Tools",
    "recipe": "Recipe",
    "places": "Places",
    "workout": "Workout",
}


def _context(caption: str | None, meta: dict, section_hint: str | None = None) -> str:
    lines = [f"{k}: {v}" for k, v in meta.items() if v]
    if caption:
        lines.append(f"caption: {caption}")
    if section_hint:
        lines.append(
            f"The user filed this video under {SECTION_NAMES.get(section_hint, section_hint)}: return a "
            f"`{section_hint}` section with everything the video gives for it (mark guesses estimated)."
        )
    return "Video metadata:\n" + "\n".join(lines) if lines else "No caption or metadata."


def extract(
    video: Path | None,
    caption: str | None,
    meta: dict,
    video_uri: str | None = None,
    section_hint: str | None = None,
) -> ExtractResult:
    """video: a local file; video_uri: a URL Gemini can read itself (YouTube). Neither: caption-only.

    Each key tries every model in MODELS before the next key. An uploaded file belongs to one key's
    project, so the video is uploaded again per key, never per model.
    """
    if not keys():
        raise RuntimeError("no Gemini key: set GEMINI_API_KEY or GEMINI_API_KEYS in backend/.env")
    busy: list[str] = []
    for n, key in enumerate(keys(), 1):
        result = _with_key(client(key), video, caption, meta, video_uri, busy, f"key{n}", section_hint)
        if result is not None:
            return result
    raise Transient("Gemini busy: " + ", ".join(busy))


def _with_key(
    c, video, caption, meta, video_uri, busy: list[str], label: str, section_hint: str | None = None
) -> ExtractResult | None:
    """None when every model on this key was busy or out of quota (reasons appended to busy)."""
    from google.genai import errors, types

    parts: list = []
    uploaded = None
    try:
        if video is not None:
            try:
                uploaded = c.files.upload(file=video, config={"mime_type": "video/mp4"})
            except errors.APIError as e:
                if e.code not in TRANSIENT:
                    raise
                busy.append(f"{label} upload {e.code}")
                return None
            while uploaded.state and uploaded.state.name == "PROCESSING":
                time.sleep(2)
                uploaded = c.files.get(name=uploaded.name)
            if uploaded.state and uploaded.state.name == "FAILED":
                raise RuntimeError("Gemini could not process the video file")
            parts.append(uploaded)
        elif video_uri:
            parts.append(types.Part.from_uri(file_uri=video_uri, mime_type="video/*"))
        else:
            parts.append("There is no video, only the caption below. Extract only what the caption states.")
        parts.append(_context(caption, meta, section_hint))

        config = types.GenerateContentConfig(
            system_instruction=PROMPT,
            response_mime_type="application/json",
            response_json_schema=gemini_schema(ExtractResult),
            temperature=0.2,
        )
        for model in MODELS:
            _pace()
            try:
                response = c.models.generate_content(model=model, contents=parts, config=config)
            except errors.APIError as e:
                if e.code not in TRANSIENT:
                    raise
                busy.append(f"{label} {model} {e.code}")
                log.warning("extract %s %s busy (%s), trying next", label, model, e.code)
                continue
            log.info("extract %s model=%s", label, model)
            return ExtractResult.model_validate_json(response.text)
        return None
    finally:
        if uploaded is not None:
            try:
                c.files.delete(name=uploaded.name)
            except Exception as e:  # noqa: BLE001 - cleanup only; files expire after 48 h anyway
                log.debug("could not delete %s: %s", uploaded.name, e)
