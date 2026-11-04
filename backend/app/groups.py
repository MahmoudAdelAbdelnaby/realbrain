"""V5 group walls: sharing a save into a group (the group gets its own copy), plans, cook-alongs
and challenges as posts, and comments with photos. Members react (RSVP, join, like) straight in
Firestore under the rules; everything here is written by the backend.

spaces/{gid}/posts/{pid}                kind, by, by_name, at, section, noun, title, detail, frame,
                                        save_id, item_id, when?, place?, text?, rsvp{}, likes{},
                                        comment_count
spaces/{gid}/posts/{pid}/comments/{cid} by, by_name, kind, text?, photo?, at
"""

import base64
import binascii
import hashlib
import logging
import time
import uuid

from fastapi import HTTPException

from app import notify, spaces, store

log = logging.getLogger("reelbrain.groups")
MAX_PHOTO_BYTES = 4 * 1024 * 1024
KIND_NOUNS = {"movie": "film", "series": "series", "book": "book"}
SECTION_NOUNS = {
    "recipe": "recipe",
    "workout": "workout",
    "places": "place",
    "tools": "tool",
    "fact_check": "fact check",
    "ideas": "idea",
    "entertainment": "title",
    "products": "product",
}
# Personal progress does not travel with a copy: the group starts it fresh.
_PERSONAL = ("user_state", "seen", "done_at", "recall_after")
_SAVE_KEEP = (
    "source_url",
    "platform",
    "creator",
    "caption",
    "summary",
    "language",
    "status",
    "sections",
    "verdict",
    "key_frame_url",
    "duration_s",
    "search_text",
    "good_for",
    "effort_min",
    "difficulty",
    "impact",
    "topics",
)


def _more(items: list) -> str:
    return f" +{len(items) - 1}" if len(items) > 1 else ""


def post_title(save: dict, item: dict | None) -> tuple[str, str]:
    """(title, detail) for the post, as the app names the item."""
    summary = save.get("summary") or "Something worth a look"
    if not item:
        return summary, ""
    d = item.get("data") or {}
    lst = d.get("items") or []
    match item.get("section"):
        case "recipe" | "ideas":
            detail = " · ".join(
                x
                for x in (
                    f"{d['total_min']} min" if d.get("total_min") else None,
                    f"serves {d['servings']}" if d.get("servings") else None,
                )
                if x
            )
            return d.get("title") or summary, detail
        case "tools" | "places" | "products":
            if not lst:
                return summary, ""
            first = lst[0]
            where = ", ".join(x for x in (first.get("area"), first.get("city")) if x)
            return f"{first.get('name')}{_more(lst)}", where
        case "entertainment":
            if not lst:
                return summary, ""
            first = lst[0]
            detail = " · ".join(
                str(x)
                for x in (KIND_NOUNS.get(first.get("kind"), "").capitalize() or None, first.get("year"))
                if x
            )
            return f"{first.get('title')}{_more(lst)}", detail
        case "workout":
            n = len(d.get("exercises") or [])
            return d.get("title") or summary, f"{n} exercise{'s' if n != 1 else ''}"
    return summary, ""


def _copy(uid: str, save: dict, group_id: str) -> dict:
    """The group's copy of a save: one per save and group (sharing twice reuses it)."""
    if save["space_id"] == group_id:
        return save
    copy_id = hashlib.sha256(f"{save['save_id']}:{group_id}".encode()).hexdigest()[:32]
    existing = store.get_save(copy_id)
    if existing:
        return existing
    fields = {k: save[k] for k in _SAVE_KEEP if k in save}
    fields.update(
        space_id=group_id,
        created_by=uid,
        shared_by=uid,
        shared_from={"space_id": save["space_id"], "save_id": save["save_id"]},
        step_text=None,
    )
    store.create_save(copy_id, fields)
    copy = store.get_save(copy_id)
    items = []
    for it in store.get_items(save):
        clean = {
            k: v
            for k, v in it.items()
            if k not in (*_PERSONAL, "item_id", "space_id", "save_id", "created_at")
        }
        items.append({**clean, "user_state": None})
    store.put_items(copy, items)
    return copy


def _notify_members(group: dict, group_id: str, by: str, title: str, body: str, data: dict) -> None:
    """A push to everyone else in the group. Never raises: the post is already up."""
    for member in group.get("members") or []:
        if member == by:
            continue
        try:
            notify.push(member, title, body, {k: str(v) for k, v in data.items() if v is not None})
        except Exception:
            log.exception("group=%s push to %s failed", group_id, member)


def share(
    uid: str, save: dict, group_id: str, item_id: str | None, kind: str, when: float | None, text: str | None
) -> dict:
    group = spaces.group(uid, group_id)
    copy = _copy(uid, save, group_id)
    items = store.get_items(copy)
    item = next((i for i in items if i.get("item_id") == item_id), None) or (items[0] if items else None)
    title, detail = post_title(copy, item)
    section = item.get("section") if item else None
    noun = SECTION_NOUNS.get(section or "", "save")
    if section == "entertainment":
        first = ((item or {}).get("data") or {}).get("items") or [{}]
        noun = KIND_NOUNS.get(first[0].get("kind"), noun)
    place = None
    if section == "places":
        first = ((item or {}).get("data") or {}).get("items") or [{}]
        place = (
            ", ".join(x for x in (first[0].get("name"), first[0].get("area"), first[0].get("city")) if x)
            or None
        )
    post_id = uuid.uuid4().hex[:16]
    name = spaces.display_name(uid)
    post = {
        "post_id": post_id,
        "kind": kind,
        "by": uid,
        "by_name": name,
        "at": time.time(),
        "section": section,
        "noun": noun,
        "title": title,
        "detail": detail,
        "frame": copy.get("key_frame_url"),
        "save_id": copy["save_id"],
        "item_id": (item or {}).get("item_id"),
        "when": when,
        "place": place,
        "text": (text or "").strip() or None,
        # The one sharing an activity is in it.
        "rsvp": {} if kind == "share" else {uid: "in" if kind == "challenge" else "going"},
        "likes": {},
        "comment_count": 0,
    }
    store.doc_set(f"spaces/{group_id}/posts/{post_id}", post)
    article = "an" if noun[:1] in "aeiou" else "a"
    verb = {"plan": "is planning a visit", "cook": "is cooking", "challenge": "challenged the group"}.get(
        kind, f"shared {article} {noun}"
    )
    _notify_members(
        group,
        group_id,
        uid,
        f"{name} {verb}",
        title,
        {"space_id": group_id, "save_id": copy["save_id"], "post_id": post_id},
    )
    return post


def _photo(group_id: str, post_id: str, b64: str) -> str:
    try:
        data = base64.b64decode(b64, validate=True)
    except (binascii.Error, ValueError):
        raise HTTPException(422, "photo is not valid base64") from None
    if len(data) > MAX_PHOTO_BYTES:
        raise HTTPException(413, "photo too large")
    # The bytes decide the type, not the client.
    if data[:3] == b"\xff\xd8\xff":
        ext = "jpg"
    elif data[:8] == b"\x89PNG\r\n\x1a\n":
        ext = "png"
    elif data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        ext = "webp"
    else:
        raise HTTPException(415, "photo must be JPEG, PNG or WebP")
    return store.put_image(group_id, f"post-{post_id}-{uuid.uuid4().hex[:10]}", data, ext)


def comment(
    uid: str, group_id: str, post_id: str, kind: str, text: str | None, photo_b64: str | None
) -> dict:
    group = spaces.group(uid, group_id)
    path = f"spaces/{group_id}/posts/{post_id}"
    post = store.doc_get(path)
    if not post:
        raise HTTPException(404, "post not found")
    photo = _photo(group_id, post_id, photo_b64) if photo_b64 else None
    name = spaces.display_name(uid)
    entry = {
        "by": uid,
        "by_name": name,
        "kind": kind,
        "text": (text or "").strip() or None,
        "photo": photo,
        "at": time.time(),
    }
    store.doc_set(f"{path}/comments/{uuid.uuid4().hex[:16]}", entry)
    update = {"comment_count": int(post.get("comment_count") or 0) + 1}
    if kind in ("proof", "result") and post.get("kind") in ("challenge", "cook"):
        # Proof of a challenge (or a cook-along result) marks you done on the post.
        update["rsvp"] = {**(post.get("rsvp") or {}), uid: "done"}
    store.doc_update(path, update)
    label = {"proof": "did the challenge", "result": "shared how it went"}.get(kind, "commented")
    _notify_members(
        group,
        group_id,
        uid,
        f"{name} {label}",
        post.get("title") or "",
        {"space_id": group_id, "save_id": post.get("save_id"), "post_id": post_id},
    )
    return entry
