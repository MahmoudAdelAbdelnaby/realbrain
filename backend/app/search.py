"""P1-15: one normalised text per save for search on the phone (Firestore has no full-text search).

Same normalisation as the app (lib/features/library/search.dart): lowercase, Arabic diacritics
and tatweel removed, alef/ya/ta-marbuta variants folded, so "طماطم" finds "طَماطِم".
"""

import re

from app.schemas import ExtractResult

MAX_CHARS = 20_000
_TASHKEEL = re.compile(r"[ؐ-ًؚ-ٰٟـ]")
_FOLD = str.maketrans({"أ": "ا", "إ": "ا", "آ": "ا", "ى": "ي", "ة": "ه", "ؤ": "و", "ئ": "ي"})


def normalise(text: str) -> str:
    return " ".join(_TASHKEEL.sub("", text.lower()).translate(_FOLD).split())


def search_text(save: dict, result: ExtractResult | None, items: list[dict]) -> str:
    parts = [save.get("caption"), save.get("creator"), save.get("source_url")]
    if result:
        parts += [result.summary, result.summary_en, *result.topics]
        parts += [line.text for line in result.transcript] + [line.text for line in result.on_screen_text]
    for item in items:
        d = item.get("data", {})
        parts.append(d.get("title"))
        parts.extend(d.get("tags") or [])
        for key in ("items", "ingredients", "exercises"):
            parts.extend(x.get("name") for x in d.get(key) or [])
        parts.extend(c.get("text") for c in d.get("claims") or [])
    return normalise(" ".join(p for p in parts if p))[:MAX_CHARS]
