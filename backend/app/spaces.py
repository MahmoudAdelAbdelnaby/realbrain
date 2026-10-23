"""Users, spaces and household invites (P1-03). Only the backend writes these; clients only read."""

import os
import secrets
import time

from fastapi import HTTPException

from app import store

INVITE_BASE = os.environ.get("INVITE_BASE", "https://reelbrain-dev.web.app/join/")
INVITE_DAYS = 7
# No 0/o/1/l/i: codes are read aloud and typed in.
_ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789"


def ensure_user(uid: str, name: str | None = None, lang: str | None = None) -> dict:
    """users/{uid} and the personal space, created on the first call; later calls return them."""
    user = store.doc_get(f"users/{uid}")
    if user:
        return user
    personal = f"p_{uid}"
    store.doc_set(
        f"spaces/{personal}",
        {"name": "Me", "type": "personal", "members": [uid], "created_by": uid, "created_at": time.time()},
    )
    user = {
        "name": name,
        "lang": lang or "en",
        "fcm_tokens": [],
        "default_space": personal,
        "spaces": {"me": personal},
    }
    store.doc_set(f"users/{uid}", user)
    return user


def is_member(uid: str, space_id: str) -> bool:
    space = store.doc_get(f"spaces/{space_id}")
    return bool(space) and uid in space.get("members", [])


def resolve(uid: str, space_id: str) -> str:
    """The phone sends "me" or "home"; anything else must be a space the caller belongs to.
    "home" without a household falls back to the personal space, so a share is never lost."""
    user = ensure_user(uid)
    if space_id in ("me", "home"):
        return user["spaces"].get(space_id) or user["spaces"]["me"]
    if not is_member(uid, space_id):
        raise HTTPException(404, "space not found")
    return space_id


def create_household(uid: str, name: str) -> tuple[str, str]:
    """One household per user: a second call returns the existing one with a fresh invite."""
    user = ensure_user(uid)
    space_id = user["spaces"].get("home")
    if not space_id:
        space_id = "h_" + secrets.token_hex(8)
        store.doc_set(
            f"spaces/{space_id}",
            {
                "name": name,
                "type": "household",
                "members": [uid],
                "created_by": uid,
                "created_at": time.time(),
            },
        )
        store.doc_update(f"users/{uid}", {"spaces": {**user["spaces"], "home": space_id}})
    return space_id, invite(uid, space_id)


def invite(uid: str, space_id: str) -> str:
    space = store.doc_get(f"spaces/{space_id}")
    if not space or uid not in space.get("members", []):
        raise HTTPException(404, "space not found")
    if space.get("type") != "household":
        raise HTTPException(400, "only a household can be shared")
    code = "".join(secrets.choice(_ALPHABET) for _ in range(8))
    store.doc_set(
        f"invites/{code}",
        {"space_id": space_id, "created_by": uid, "expires_at": time.time() + INVITE_DAYS * 86400},
    )
    return INVITE_BASE + code


def accept(uid: str, code: str) -> str:
    code = code.strip().lower()
    inv = store.doc_get(f"invites/{code}") if code.isalnum() else None
    if not inv:
        raise HTTPException(404, "invite not found")
    if inv["expires_at"] < time.time():
        raise HTTPException(410, "invite expired, ask for a new link")
    user = ensure_user(uid)
    store.doc_array_add(f"spaces/{inv['space_id']}", "members", uid)
    # Joining someone's household makes it your Home share target.
    store.doc_update(f"users/{uid}", {"spaces": {**user["spaces"], "home": inv["space_id"]}})
    return inv["space_id"]
