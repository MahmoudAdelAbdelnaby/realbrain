"""Recall (design v4 step 4): once a day, each person gets one "Remember this?" push for the
oldest memory they saved over a week ago and never tried. The phone's Recall tab uses the same
rule (app/lib/features/recall/recall.dart): change both together.
"""

import logging
import time
from datetime import datetime

from app import notify, store

log = logging.getLogger("reelbrain.recall")
WEEK = 7 * 86400
SEND_AFTER_HOUR = 19  # local time: evening, when people browse what they saved
READY = {"ready", "partial"}


def due(saves: list[dict], items: list[dict], now: float) -> list[tuple[dict, dict]]:
    """(item, save) still to try, saved over a week ago and not snoozed, oldest first."""
    by_id = {s.get("save_id"): s for s in saves}
    out = []
    for item in items:
        save = by_id.get(item.get("save_id"))
        if (
            save is None
            or save.get("status") not in READY
            or item.get("user_state") not in (None, "to_try")
            or (save.get("created_at") or now) > now - WEEK
            or (item.get("recall_after") or 0) > now
        ):
            continue
        out.append((item, save))
    return sorted(out, key=lambda p: p[1].get("created_at") or 0)


def ago(seconds: float) -> str:
    days = int(seconds // 86400)
    if days < 14:
        return f"{days} days"
    if days < 60:
        return f"{days // 7} weeks"
    return f"{days // 30} months"


def run_once(now: float | None = None) -> int:
    """Sends today's Recall pushes; returns how many people got one."""
    now = now or time.time()
    today = datetime.fromtimestamp(now).strftime("%Y-%m-%d")
    sent = 0
    for uid, user in store.col_items("users"):
        if user.get("recall_sent_on") == today or (user.get("settings") or {}).get("recall") is False:
            continue
        saves, items = [], []
        for space_id in set((user.get("spaces") or {}).values()):
            for save in store.col_list(f"spaces/{space_id}/saves"):
                saves.append(save)
                if save.get("status") in READY:
                    items += store.get_items(save)
        picks = due(saves, items, now)
        if not picks:
            continue
        _, save = picks[0]
        try:
            n = notify.push(
                uid,
                "Remember this?",
                f"{ago(now - save['created_at'])} ago you saved: {save.get('summary') or 'something to try'}",
                {"save_id": save["save_id"], "space_id": save["space_id"], "recall": "1"},
            )
        except Exception:
            log.exception("recall push to %s failed", uid)
            continue
        store.doc_update(f"users/{uid}", {"recall_sent_on": today})
        sent += n > 0
    return sent


def loop() -> None:
    """Checks every 30 minutes; sends once a day per person after SEND_AFTER_HOUR."""
    while True:
        try:
            if datetime.now().hour >= SEND_AFTER_HOUR:
                log.info("recall: %d sent", run_once())
        except Exception:
            log.exception("recall run failed")
        time.sleep(30 * 60)
