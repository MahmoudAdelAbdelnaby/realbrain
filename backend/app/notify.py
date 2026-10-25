"""Push notifications (P1-06): one FCM message to the saver when a save is ready."""

import logging

from app import store
from app.schemas import ExtractResult

log = logging.getLogger("reelbrain.notify")
TITLE_MAX = 60  # AI contract: notification line of at most 60 characters


def _cut(text: str, n: int) -> str:
    text = " ".join(text.split())
    return text if len(text) <= n else text[: n - 1].rstrip() + "…"


def _more(items: list) -> str:
    return f" +{len(items) - 1} more" if len(items) > 1 else ""


def key_line(result: ExtractResult, partial: bool = False) -> tuple[str, str]:
    """(title, body): the key result of the most confident section, then the summary."""
    body = _cut(result.summary or "", 140)
    if not result.sections:
        return ("Saved, needs a look" if not partial else "Saved from the caption only"), body
    s = max(result.sections, key=lambda x: x.confidence)
    match s.type:
        case "recipe":
            title = f"Recipe ready: {s.title}"
        case "tools":
            title = f"Tool saved: {s.items[0].name}{_more(s.items)}" if s.items else "Tools saved"
        case "places":
            p = s.items[0] if s.items else None
            where = f", {p.area or p.city}" if p and (p.area or p.city) else ""
            title = f"Place saved: {p.name}{where}{_more(s.items)}" if p else "Places saved"
        case "workout":
            n = len(s.exercises)
            title = f"Workout saved: {n} exercise{'s' if n != 1 else ''}"
        case "fact_check":
            # P1-08 replaces this with the verdict line once grounding exists.
            n = len(s.claims)
            title = f"Fact check: {n} claim{'s' if n != 1 else ''} to check"
        case _:
            title = "Saved"
    if partial:
        title = "Caption only · " + title
    return _cut(title, TITLE_MAX), body


def push(uid: str, title: str, body: str, data: dict[str, str]) -> int:
    """One push to every phone of uid; drops tokens FCM says are gone. Raises on FCM errors."""
    user = store.doc_get(f"users/{uid}") or {}
    tokens = user.get("fcm_tokens") or []
    if not tokens or not store.FIRESTORE:
        return 0
    from firebase_admin import messaging

    from app.auth import firebase_app

    # users.fcm_tokens holds Firebase installation IDs (FIDs), FCM's current send target.
    msg = messaging.MulticastMessage(
        fids=tokens,
        notification=messaging.Notification(title=_cut(title, TITLE_MAX), body=body),
        data=data,
        android=messaging.AndroidConfig(priority="high"),
    )
    resp = messaging.send_each_for_multicast(msg, app=firebase_app())
    gone = [t for t, r in zip(tokens, resp.responses) if isinstance(r.exception, messaging.UnregisteredError)]
    if gone:
        store.doc_update(f"users/{uid}", {"fcm_tokens": [t for t in tokens if t not in gone]})
    return resp.success_count


def send(save: dict, result: ExtractResult, partial: bool = False, title: str | None = None) -> int:
    """Notifies the person who saved it. Never raises."""
    try:
        line, body = key_line(result, partial)
        sent = push(
            save["created_by"],
            title or line,  # Fact Check: the grounded verdict line
            body,
            {"save_id": save["save_id"], "space_id": save["space_id"]},
        )
        log.info("save=%s push sent=%d", save["save_id"], sent)
        return sent
    except Exception:
        log.exception("save=%s push failed (the save itself is fine)", save.get("save_id"))
        return 0
