"""P1-16 cost guard: a daily cap of saves per user, and Gemini calls counted per model per day
(shown in Settings against the free-tier limits). Days are UTC."""

import logging
import threading
import time

from fastapi import HTTPException

from app import store

DEFAULT_CAP = 20
_lock = threading.Lock()
# Free tier seen in AI Studio on 24 Oct 2026 (requests per day), for the Settings screen.
FREE_RPD = {
    "gemini-3.6-flash": 20,
    "gemini-3.8-flash": 20,
    "gemini-3.5-flash-lite": 500,
    "gemini-3.1-flash-lite": 500,
    "gemini-2.5-flash-lite": 20,
}


def today() -> str:
    return time.strftime("%Y-%m-%d", time.gmtime())


def check_and_count_save(uid: str) -> int:
    """Counts one save for today; 429 past the user's cap. Returns today's count."""
    with _lock:
        user = store.doc_get(f"users/{uid}") or {}
        cap = int((user.get("settings") or {}).get("daily_cap") or DEFAULT_CAP)
        used = user.get("saves_today") or {}
        count = used.get("count", 0) if used.get("date") == today() else 0
        if count >= cap:
            raise HTTPException(429, f"Daily limit of {cap} saves reached. It resets at midnight UTC.")
        store.doc_update(f"users/{uid}", {"saves_today": {"date": today(), "count": count + 1}})
        return count + 1


def count_model(model: str) -> None:
    """One Gemini call; never raises (counting must not break a save)."""
    try:
        with _lock:
            path = f"usage/{today()}"
            doc = store.doc_get(path) or {}
            store.doc_set(path, {**doc, model: doc.get(model, 0) + 1})
    except Exception as e:  # noqa: BLE001
        logging.getLogger("reelbrain.usage").debug("usage count failed: %s", e)


def model_usage() -> list[dict]:
    doc = store.doc_get(f"usage/{today()}") or {}
    names = list(dict.fromkeys([*FREE_RPD, *doc]))
    return [{"model": m, "used": doc.get(m, 0), "free_per_day": FREE_RPD.get(m)} for m in names]
