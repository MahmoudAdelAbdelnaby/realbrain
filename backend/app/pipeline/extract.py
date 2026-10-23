"""Call 1, Extract: one Gemini call that watches the video and fills the AI contract."""

import logging
import os
import time
from functools import cache
from pathlib import Path

from app.schemas import ExtractResult, gemini_schema

log = logging.getLogger("reelbrain.extract")

# Free tier (AI Studio, 24 Oct 2026): each Flash model has its own 20 requests/day, Flash-Lite 500/day.
# Busy or out of quota -> the next model, so one save never burns a retry on the same overloaded model.
# 3.6 first: 3.8 answered in 200 s and 503'd repeatedly on the spike day; 3.6 in 3 s.
MODELS = os.environ.get("GEMINI_MODELS", "gemini-3.6-flash,gemini-3.8-flash,gemini-3.5-flash-lite").split(",")
MODEL = MODELS[0]
TRANSIENT = (408, 429, 500, 502, 503, 504)
PROMPT = (Path(__file__).resolve().parent.parent / "prompts" / "extract.md").read_text("utf-8")


class Transient(Exception):
    """Worth retrying later (quota, overload, timeouts): the job is retried, not failed."""


@cache
def client():
    from google import genai

    return genai.Client(api_key=os.environ["GEMINI_API_KEY"])


def _context(caption: str | None, meta: dict) -> str:
    lines = [f"{k}: {v}" for k, v in meta.items() if v]
    if caption:
        lines.append(f"caption: {caption}")
    return "Video metadata:\n" + "\n".join(lines) if lines else "No caption or metadata."


def extract(
    video: Path | None, caption: str | None, meta: dict, video_uri: str | None = None
) -> ExtractResult:
    """video: a local file; video_uri: a URL Gemini can read itself (YouTube). Neither: caption-only."""
    from google.genai import errors, types

    parts: list = []
    uploaded = None
    try:
        if video is not None:
            uploaded = client().files.upload(file=video, config={"mime_type": "video/mp4"})
            while uploaded.state and uploaded.state.name == "PROCESSING":
                time.sleep(2)
                uploaded = client().files.get(name=uploaded.name)
            if uploaded.state and uploaded.state.name == "FAILED":
                raise RuntimeError("Gemini could not process the video file")
            parts.append(uploaded)
        elif video_uri:
            parts.append(types.Part.from_uri(file_uri=video_uri, mime_type="video/*"))
        else:
            parts.append("There is no video, only the caption below. Extract only what the caption states.")
        parts.append(_context(caption, meta))

        config = types.GenerateContentConfig(
            system_instruction=PROMPT,
            response_mime_type="application/json",
            response_json_schema=gemini_schema(ExtractResult),
            temperature=0.2,
        )
        busy = []
        for model in MODELS:
            try:
                response = client().models.generate_content(model=model, contents=parts, config=config)
            except errors.APIError as e:
                if e.code not in TRANSIENT:
                    raise
                busy.append(f"{model} {e.code}")
                log.warning("extract on %s busy (%s), trying next model", model, e.code)
                continue
            log.info("extract model=%s", model)
            return ExtractResult.model_validate_json(response.text)
        raise Transient("Gemini busy: " + ", ".join(busy))
    finally:
        if uploaded is not None:
            try:
                client().files.delete(name=uploaded.name)
            except Exception as e:  # noqa: BLE001 - cleanup only; files expire after 48 h anyway
                log.debug("could not delete %s: %s", uploaded.name, e)
