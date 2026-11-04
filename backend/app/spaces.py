"""Users, spaces, groups and invites (P1-03, V5 groups). Only the backend writes these; clients only
read (and, under the rules, react to posts).

A person has a personal space (`spaces.me`) and any number of groups (`groups`). `spaces.home` is
the group the "Realbrain · Home" share target saves into: the first group made or joined, or the
one picked as the share target. Households made before V5 are groups of type "household".
"""

import os
import secrets
import time

from fastapi import HTTPException

from app import store

INVITE_BASE = os.environ.get("INVITE_BASE", "https://reelbrain-dev.web.app/join/")
INVITE_DAYS = 7
GROUP_TYPES = ("household", "group")
# No 0/o/1/l/i: codes are read aloud and typed in.
_ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789"


def ensure_user(uid: str, name: str | None = None, lang: str | None = None) -> dict:
    """users/{uid} and the personal space, created on the first call; later calls return them."""
    user = store.doc_get(f"users/{uid}")
    if user:
        # Firebase may not have the display name yet on the very first call; fill it in later.
        missing = {k: v for k, v in (("name", name), ("lang", lang)) if v and not user.get(k)}
        if missing:
            store.doc_update(f"users/{uid}", missing)
            user.update(missing)
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


def display_name(uid: str, user: dict | None = None) -> str:
    """The first name a group shows for a member."""
    name = ((user or store.doc_get(f"users/{uid}") or {}).get("name") or "").strip()
    return name.split()[0] if name else "Someone"


def groups_of(user: dict) -> list[str]:
    """Group ids, including a household made before V5 (it was only in spaces.home)."""
    listed = list(user.get("groups") or [])
    home = (user.get("spaces") or {}).get("home")
    if home and home not in listed:
        listed.append(home)
    return listed


def backfill_names(uid: str, user: dict) -> None:
    """Puts uid's first name on each of their groups that doesn't show it yet (groups and
    households from before V5 have no member_names)."""
    for space_id in groups_of(user):
        space = store.doc_get(f"spaces/{space_id}")
        if space and uid in space.get("members", []) and uid not in (space.get("member_names") or {}):
            store.doc_update(
                f"spaces/{space_id}",
                {"member_names": {**(space.get("member_names") or {}), uid: display_name(uid, user)}},
            )


def is_member(uid: str, space_id: str) -> bool:
    space = store.doc_get(f"spaces/{space_id}")
    return bool(space) and uid in space.get("members", [])


def group(uid: str, space_id: str) -> dict:
    """The group, if uid is a member (404 otherwise, so ids can't be probed)."""
    space = store.doc_get(f"spaces/{space_id}")
    if not space or uid not in space.get("members", []):
        raise HTTPException(404, "group not found")
    if space.get("type") not in GROUP_TYPES:
        raise HTTPException(400, "not a group")
    return space


def resolve(uid: str, space_id: str) -> str:
    """The phone sends "me" or "home"; anything else must be a space the caller belongs to.
    "home" without a group falls back to the personal space, so a share is never lost."""
    user = ensure_user(uid)
    if space_id in ("me", "home"):
        return user["spaces"].get(space_id) or user["spaces"]["me"]
    if not is_member(uid, space_id):
        raise HTTPException(404, "space not found")
    return space_id


def _join(uid: str, space_id: str, user: dict) -> None:
    """Adds uid to the group, its name to the group, the group to uid's list; the first group
    becomes the Home share target."""
    store.doc_array_add(f"spaces/{space_id}", "members", uid)
    space = store.doc_get(f"spaces/{space_id}") or {}
    store.doc_update(
        f"spaces/{space_id}",
        {"member_names": {**(space.get("member_names") or {}), uid: display_name(uid, user)}},
    )
    store.doc_array_add(f"users/{uid}", "groups", space_id)
    spaces = user.get("spaces") or {}
    if not spaces.get("home"):
        store.doc_update(f"users/{uid}", {"spaces": {**spaces, "home": space_id}})


def create_group(uid: str, name: str, kind: str = "group") -> str:
    user = ensure_user(uid)
    space_id = ("h_" if kind == "household" else "g_") + secrets.token_hex(8)
    store.doc_set(
        f"spaces/{space_id}",
        {
            "name": name,
            "type": kind,
            "members": [],
            "member_names": {},
            "created_by": uid,
            "created_at": time.time(),
        },
    )
    _join(uid, space_id, user)
    return space_id


def create_household(uid: str, name: str) -> tuple[str, str]:
    """Pre-V5 route: one household per user; a second call returns it with a fresh invite."""
    user = ensure_user(uid)
    space_id = user["spaces"].get("home") or create_group(uid, name, kind="household")
    return space_id, invite(uid, space_id)


def invite(uid: str, space_id: str) -> str:
    space = store.doc_get(f"spaces/{space_id}")
    if not space or uid not in space.get("members", []):
        raise HTTPException(404, "space not found")
    if space.get("type") not in GROUP_TYPES:
        raise HTTPException(400, "only a group can be shared")
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
    _join(uid, inv["space_id"], ensure_user(uid))
    return inv["space_id"]


def set_default(uid: str, space_id: str) -> None:
    """Makes a group the "Realbrain · Home" share target."""
    group(uid, space_id)
    user = ensure_user(uid)
    store.doc_update(f"users/{uid}", {"spaces": {**user["spaces"], "home": space_id}})


def leave(uid: str, space_id: str) -> None:
    """Leaves a group; if it was the share target, the next group (if any) takes over."""
    space = group(uid, space_id)
    store.doc_array_remove(f"spaces/{space_id}", "members", uid)
    names = {k: v for k, v in (space.get("member_names") or {}).items() if k != uid}
    store.doc_update(f"spaces/{space_id}", {"member_names": names})
    user = ensure_user(uid)
    rest = [g for g in groups_of(user) if g != space_id]
    store.doc_update(f"users/{uid}", {"groups": rest})
    spaces = dict(user.get("spaces") or {})
    if spaces.get("home") == space_id:
        if rest:
            spaces["home"] = rest[0]
        else:
            spaces.pop("home", None)
        store.doc_update(f"users/{uid}", {"spaces": spaces})
