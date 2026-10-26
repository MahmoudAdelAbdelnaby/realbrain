import hashlib
import logging
import os
import re
import secrets
import time
import uuid
from typing import Annotated
from urllib.parse import urlparse

from fastapi import BackgroundTasks, Depends, FastAPI, Header, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse

from app import spaces, store, tasks, usage
from app.auth import claims, cloud_tasks, user
from app.pipeline.extract import Transient
from app.pipeline.process import process
from app.schemas import (
    CreatedSave,
    CreateHousehold,
    CreateList,
    CreateSave,
    FileUnder,
    Me,
    NoVideo,
    ProcessTask,
    Settings,
)

logging.basicConfig(level=logging.INFO)
if not (os.environ.get("GEMINI_API_KEY") or os.environ.get("GEMINI_API_KEYS")):
    logging.getLogger("reelbrain").warning(
        "GEMINI_API_KEY is not set: saves will upload but fail at Extract. Add it to backend/.env."
    )
# Reachable from the internet through the tunnel: no API explorer outside local dev.
_dev_docs = os.environ.get("AUTH_MODE") == "dev"
app = FastAPI(
    title="Reelbrain API",
    docs_url="/docs" if _dev_docs else None,
    redoc_url=None,
    openapi_url="/openapi.json" if _dev_docs else None,
)
# I1: the iPhone web app (Firebase Hosting) calls the API from the browser.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://reelbrain-app.web.app"],
    allow_methods=["*"],
    allow_headers=["Authorization", "Content-Type"],
)
MAX_VIDEO_BYTES = 200 * 1024 * 1024


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


def platform(url: str) -> str:
    host = urlparse(url).hostname or ""
    for name, marks in {
        "tiktok": ("tiktok.com",),
        "instagram": ("instagram.com",),
        "youtube": ("youtube.com", "youtu.be"),
    }.items():
        if any(host == m or host.endswith("." + m) for m in marks):
            return name
    return "other"


def owned_save(save_id: str, uid: str) -> dict:
    """The save, if the caller is a member of its space (404 otherwise, so ids can't be probed)."""
    save = store.get_save(save_id)
    if save is None or not spaces.is_member(uid, save["space_id"]):
        raise HTTPException(404, "save not found")
    return save


@app.post("/v1/me")
def me(body: Me, token: Annotated[dict, Depends(claims)]) -> dict:
    """First call creates users/{uid} and the personal space; later calls just return them.
    The name comes from the Google sign-in token when the app doesn't have it yet."""
    uid = token["uid"]
    u = spaces.ensure_user(uid, body.name or token.get("name"), body.lang)
    if body.fcm_token:
        store.doc_array_add(f"users/{uid}", "fcm_tokens", body.fcm_token)
    return {"uid": uid, "spaces": u["spaces"]}


@app.get("/v1/settings")
def get_settings(uid: str = Depends(user)) -> dict:
    """P1-16: your settings, today's saves, and Gemini use against free limits."""
    u = spaces.ensure_user(uid)
    s = u.get("settings") or {}
    used = u.get("saves_today") or {}
    from app.pipeline.extract import MODELS, keys

    return {
        "settings": {
            "lang": s.get("lang", "system"),
            "theme": s.get("theme", "system"),
            "recall": s.get("recall", True),
        },
        "saves_today": used.get("count", 0) if used.get("date") == usage.today() else 0,
        "gemini": {"keys": len(keys()), "models": MODELS, "usage_today": usage.model_usage()},
        "billing": "Spark plan: $0, no billing account"
        if not store.BUCKET
        else "Blaze: check the $1 budget alert",
    }


@app.patch("/v1/settings")
def patch_settings(body: Settings, uid: str = Depends(user)) -> dict:
    u = spaces.ensure_user(uid)
    merged = {**(u.get("settings") or {}), **body.model_dump(exclude_none=True)}
    store.doc_update(f"users/{uid}", {"settings": merged})
    return {"settings": merged}


@app.post("/v1/spaces/household")
def create_household(body: CreateHousehold, uid: str = Depends(user)) -> dict:
    space_id, url = spaces.create_household(uid, body.name)
    return {"space_id": space_id, "invite_url": url}


@app.post("/v1/spaces/{space_id}/invite")
def new_invite(space_id: str, uid: str = Depends(user)) -> dict:
    return {"invite_url": spaces.invite(uid, space_id)}


@app.post("/v1/spaces/{space_id}/lists")
def create_list(space_id: str, body: CreateList, uid: str = Depends(user)) -> dict:
    """A named list in a space (workout routine, place list, recipe collection). Members then edit
    its item_refs and per-item overrides directly (rules); creating it stays on the backend."""
    space_id = spaces.resolve(uid, space_id)
    list_id = uuid.uuid4().hex[:12]
    store.doc_set(
        f"spaces/{space_id}/lists/{list_id}",
        {
            "list_id": list_id,
            "space_id": space_id,
            "section": body.section,
            "name": body.name,
            "item_refs": [],
            "overrides": {},
            "created_by": uid,
            "created_at": time.time(),
        },
    )
    return {"list_id": list_id, "space_id": space_id}


@app.post("/v1/invites/{code}/accept")
def accept_invite(code: str, uid: str = Depends(user)) -> dict:
    return {"space_id": spaces.accept(uid, code)}


@app.post("/v1/saves", response_model=CreatedSave)
def create_save(body: CreateSave, uid: str = Depends(user)) -> CreatedSave:
    space_id = spaces.resolve(uid, body.space_id)
    if body.client_id:
        # Idempotent per share: a retry after a failed upload gets the same save and a fresh
        # upload URL (the tunnel's address may have changed since).
        save_id = hashlib.sha256(f"{uid}:{body.client_id}".encode()).hexdigest()[:32]
        existing = store.get_save(save_id)
        if existing is not None:
            return CreatedSave(
                save_id=save_id,
                upload_url=store.upload_url(save_id),
                status=existing.get("status", "received"),
            )
    else:
        save_id = uuid.uuid4().hex
    usage.count_save(uid)  # P1-16, shown in Settings
    store.create_save(
        save_id,
        {
            "source_url": body.source_url,
            "platform": platform(body.source_url) if body.source_url else "idea",
            "space_id": space_id,
            "note": body.note,
            "caption": body.caption or body.idea,
            "creator": body.creator,
            "status": "received",
            "step_text": None,
            "created_by": uid,
            # Create's "What is this?"; a typed idea is an idea unless it says otherwise.
            "forced_section": body.section_hint or ("ideas" if body.idea else None),
        },
    )
    if body.idea:
        # Nothing to upload: read it straight away.
        tasks.enqueue(save_id)
        return CreatedSave(save_id=save_id, upload_url="", status="uploaded")
    return CreatedSave(save_id=save_id, upload_url=store.upload_url(save_id))


@app.post("/v1/saves/{save_id}/uploaded", status_code=202)
def uploaded(save_id: str, uid: str = Depends(user)) -> dict:
    save = owned_save(save_id, uid)
    store.update_save(save, {"status": "uploaded", "step_text": "Queued"})
    tasks.enqueue(save_id)
    return {"save_id": save_id}


@app.post("/v1/saves/{save_id}/no-video", status_code=202)
def no_video(save_id: str, body: NoVideo, uid: str = Depends(user)) -> dict:
    """The phone couldn't fetch the video: the backend tries its fallback chain."""
    save = owned_save(save_id, uid)
    store.update_save(
        save, {"status": "fetching", "step_text": "Getting the video", "no_video_reason": body.reason}
    )
    tasks.enqueue(save_id)
    return {"save_id": save_id}


def _key_hash(key: str) -> str:
    return hashlib.sha256(key.encode()).hexdigest()


@app.post("/v1/me/save-key")
def new_save_key(uid: str = Depends(user)) -> dict:
    """I2: the key the iPhone Shortcut saves with. Shown once; a new one replaces the old."""
    key = secrets.token_urlsafe(24)
    store.doc_set(f"save_keys/{_key_hash(key)}", {"uid": uid})
    # Only the current hash counts, so the old key stops working without deleting its doc.
    store.doc_update(f"users/{uid}", {"save_key_hash": _key_hash(key)})
    return {"key": key}


@app.post("/v1/shortcut/save", status_code=202)
def shortcut_save(body: dict, x_save_key: str | None = Header(None)) -> dict:
    """I2: Share → Save to Realbrain. The link goes the web app's way: save, then the backend fetches."""
    h = _key_hash(x_save_key or "")
    owner = (store.doc_get(f"save_keys/{h}") or {}).get("uid")
    if not owner or (store.doc_get(f"users/{owner}") or {}).get("save_key_hash") != h:
        raise HTTPException(401, "invalid save key")
    # Share sheets often send text around the link ("Check this out https://...").
    m = re.search(r"https?://\S+", str(body.get("url") or ""))
    if not m:
        raise HTTPException(422, "no link")
    url = m.group(0)
    # The Shortcut's "Me or Home?" menu; Home without a household lands in Me (spaces.resolve).
    space = "home" if str(body.get("space") or "").strip().lower() == "home" else "me"
    # Same link within a minute = the same save, so a double tap doesn't make two.
    client_id = hashlib.sha256(f"{url}:{space}:{int(time.time() // 60)}".encode()).hexdigest()[:32]
    created = create_save(CreateSave(source_url=url, space_id=space, client_id=client_id), owner)
    if created.status == "received":
        no_video(created.save_id, NoVideo(reason="ios shortcut"), owner)
    return {"save_id": created.save_id}


@app.post("/v1/saves/{save_id}/retry", status_code=202)
def retry(save_id: str, uid: str = Depends(user)) -> dict:
    save = owned_save(save_id, uid)
    store.update_save(save, {"status": "received", "step_text": "Retrying"})
    tasks.enqueue(save_id)
    return {"save_id": save_id}


@app.post("/v1/saves/{save_id}/section")
def file_under(save_id: str, body: FileUnder, uid: str = Depends(user)) -> dict:
    """User correction (Inbox, or "Wrong section?"): logged for prompt tuning, then Extract runs
    again with the section as a hint, on the kept video or through the fallback chain."""
    save = owned_save(save_id, uid)
    store.doc_set(
        f"corrections/{uuid.uuid4().hex}",
        {
            "save_id": save_id,
            "space_id": save["space_id"],
            "by": uid,
            "from_status": save.get("status"),
            "from_sections": save.get("sections") or [],
            "to_section": body.section,
            "language": save.get("language"),
            "at": time.time(),
        },
    )
    if body.section == "none":
        # Nothing to re-read for: a plain save with no section, out of the Inbox.
        store.put_items(save, [])
        store.update_save(
            save, {"status": "ready", "sections": [], "forced_section": "none", "step_text": None}
        )
        store.delete_video(save_id)
        return {"save_id": save_id}
    store.update_save(
        save, {"status": "received", "forced_section": body.section, "step_text": "Re-reading the video"}
    )
    tasks.enqueue(save_id)
    return {"save_id": save_id}


@app.post("/v1/saves/{save_id}/deep-dive", status_code=202)
def deep_dive(save_id: str, background: BackgroundTasks, uid: str = Depends(user)) -> dict:
    """P1-08 "Dive deeper": a grounded explainer for the save's Fact Check claims, written into
    the item when ready (the app listens). Also checks the claims if that failed at save time."""
    save = owned_save(save_id, uid)
    item = next((i for i in store.get_items(save) if i.get("section") == "fact_check"), None)
    if item is None:
        raise HTTPException(404, "no fact check on this save")
    background.add_task(_deep_dive, save, item)
    return {"save_id": save_id}


def _deep_dive(save: dict, item: dict) -> None:
    # ponytail: FastAPI background task; on Cloud Run this belongs on the Tasks queue (CPU after response).
    from app.pipeline import enrich

    path = f"spaces/{save['space_id']}/saves/{save['save_id']}/items/{_item_id(save, item)}"
    try:
        data = dict(item["data"])
        if not any("verdict" in c for c in data.get("claims", [])):
            data.update(enrich.check(data["claims"], save.get("language")))
        data.update(enrich.explain(data["claims"], save.get("language")))
        data.pop("explain_error", None)
    except Exception as e:  # noqa: BLE001 - shown to the user instead of an explainer
        logging.getLogger("reelbrain").warning("save=%s deep dive failed: %s", save["save_id"], e)
        data = {**item["data"], "explain_error": "Couldn't build the explainer right now. Try again later."}
    store.doc_update(path, {"data": data})


def _item_id(save: dict, item: dict) -> str:
    if item.get("item_id"):
        return item["item_id"]
    sections = [i.get("section") for i in store.get_items(save)]  # items written before item_id existed
    return f"{sections.index(item['section'])}-{item['section']}"


@app.post("/internal/process", dependencies=[Depends(cloud_tasks)])
def internal_process(
    body: ProcessTask,
    response: Response,
    retry_count: int = Header(0, alias="X-CloudTasks-TaskRetryCount"),
) -> dict:
    try:
        return {"status": process(body.save_id, attempt=retry_count)}
    except LookupError:
        return {"status": "missing"}  # 200 so Cloud Tasks drops it
    except Transient:
        response.status_code = 503  # Cloud Tasks retries with backoff
        return {"status": "retry"}


# --- local dev only: stand-ins for signed Storage URLs ---

if not store.BUCKET:

    @app.put("/dev/uploads/{save_id}")
    async def dev_upload(save_id: str, request: Request) -> dict:
        # The unguessable save id is the credential, like a signed URL; one upload per save.
        save = store.get_save(save_id)
        if save is None or save.get("status") != "received":
            raise HTTPException(404, "save not found")
        size = 0
        with store.local_video(save_id).open("wb") as f:
            async for chunk in request.stream():
                size += len(chunk)
                if size > MAX_VIDEO_BYTES:
                    raise HTTPException(413, "video too large")
                f.write(chunk)
        return {"bytes": size}

    @app.get("/dev/frames/{space_id}/{name}")
    def dev_frame(space_id: str, name: str) -> FileResponse:
        path = store.DATA / "frames" / space_id / name
        if ".." in space_id or ".." in name or not path.exists():
            raise HTTPException(404)
        return FileResponse(path)
