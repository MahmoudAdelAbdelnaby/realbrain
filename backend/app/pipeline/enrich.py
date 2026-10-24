"""Call 2, Fact Check grounding (P1-08): Gemini + Google Search on the extracted claims.

Free tier, 24 Oct 2026: search grounding works only on Gemini 2.5 (1,500/day), and of the 2.5
models only Flash-Lite is still offered to new keys, so that is the default.
"""

import json
import logging
import os
import time
from typing import Literal
from urllib.parse import quote_plus

from pydantic import BaseModel, Field, ValidationError

from app import usage
from app.pipeline.extract import TRANSIENT, Transient, _pace, client, keys

log = logging.getLogger("reelbrain.enrich")
MODELS = os.environ.get("GEMINI_GROUNDING_MODELS", "gemini-2.5-flash-lite").split(",")
Verdict = Literal["true", "mixed", "false", "unverifiable"]


class ClaimCheck(BaseModel):
    verdict: Verdict
    correction: str | None = Field(None, description="One line; what is actually true, if it differs")


class FactCheckResult(BaseModel):
    claims: list[ClaimCheck]
    overall: Literal["true", "mostly_true", "mixed", "mostly_false", "false", "unverifiable"]
    notification: str = Field(description="At most 60 characters, leads with the verdict")


PROMPT = """You check claims from a short social video. Search the web for every claim before you
answer, and base each verdict on what you find (not on memory). For each numbered claim,
in the same order, give a verdict: "true", "mixed" (partly right or missing key context),
"false", or "unverifiable" (no reliable source either way). Add a one-line correction when the
verdict isn't "true". Then an overall verdict for the video ("true", "mostly_true", "mixed",
"mostly_false", "false", "unverifiable") and a notification line of at most 60 characters that
leads with the verdict, e.g. "Mostly false: lemon water doesn't detox the liver".
Write the corrections and the notification in {language}.
Reply with JSON only: {{"claims": [{{"verdict": ..., "correction": ...}}], "overall": ..., "notification": ...}}

Claims:
{claims}"""

EXPLAIN = """Explain, for a curious non-expert, what the evidence says about the claims below from a
short social video. Use Google Search. 150-250 words in {language}, plain sentences, no headings,
mention where the science or facts are unsettled. Claims:
{claims}"""


def _json(text: str) -> dict:
    """The JSON object in a grounded reply (search tools can't be combined with JSON mode)."""
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end <= start:
        raise ValueError("no JSON in the grounded reply")
    return json.loads(text[start : end + 1])


def _line(text: str, n: int = 60) -> str:
    """Notification line: at most n characters, cut at a word boundary."""
    text = " ".join(text.split())
    if len(text) <= n:
        return text
    cut = text[: n - 1].rsplit(" ", 1)[0].rstrip(",;:")
    return cut + "…"


def _sources(response, limit: int = 5) -> list[dict]:
    meta = response.candidates[0].grounding_metadata if response.candidates else None
    seen, out = set(), []
    for chunk in meta.grounding_chunks if meta and meta.grounding_chunks else []:
        web = chunk.web
        if web and web.uri and web.uri not in seen:
            seen.add(web.uri)
            out.append({"title": web.title or web.uri, "url": web.uri})
    if not out and meta and meta.web_search_queries:
        # Searched, but the JSON reply carries no citations: link the searches themselves rather
        # than trusting URLs the model might write from memory.
        out = [
            {"title": f"Search: {q}", "url": f"https://www.google.com/search?q={quote_plus(q)}"}
            for q in meta.web_search_queries
        ]
    return out[:limit]


def _grounded(prompt: str):
    """First model/key that answers; Transient if all are busy."""
    from google.genai import errors, types

    config = types.GenerateContentConfig(
        tools=[types.Tool(google_search=types.GoogleSearch())], temperature=0.1
    )
    busy = []
    for key in keys():
        for model in MODELS:
            _pace()
            usage.count_model(model)
            try:
                return client(key).models.generate_content(model=model, contents=prompt, config=config)
            except errors.APIError as e:
                if e.code not in TRANSIENT:
                    raise
                busy.append(f"{model} {e.code}")
    raise Transient("grounding busy: " + ", ".join(busy))


def check(claims: list[dict], language: str | None) -> dict:
    """Merges verdicts into the claims; returns the fact_check item's new data fields."""
    numbered = "\n".join(f"{i + 1}. {c['text']}" for i, c in enumerate(claims))
    response = _grounded(PROMPT.format(claims=numbered, language=language or "the claims' language"))
    try:
        result = FactCheckResult.model_validate(_json(response.text))
    except (ValueError, ValidationError) as e:
        raise ValueError(f"unreadable fact check reply: {e}") from e
    sources = _sources(response)
    checked = [
        {
            **c,
            **(result.claims[i].model_dump() if i < len(result.claims) else {"verdict": "unverifiable"}),
        }
        for i, c in enumerate(claims)
    ]
    return {
        "claims": checked,
        "overall": result.overall,
        "notification": _line(result.notification),
        "sources": sources,
        "checked_at": time.time(),
        "ai_generated": True,
    }


def explain(claims: list[dict], language: str | None) -> dict:
    numbered = "\n".join(f"- {c['text']}" for c in claims)
    response = _grounded(EXPLAIN.format(claims=numbered, language=language or "the claims' language"))
    return {
        "explainer": response.text.strip(),
        "explainer_sources": _sources(response),
        "explained_at": time.time(),
    }
