import logging
import uuid
from urllib.parse import urlparse

from fastapi import Depends, FastAPI, Header, HTTPException, Request, Response
from fastapi.responses import FileResponse

from app import store, tasks
from app.auth import cloud_tasks, user
from app.pipeline.extract import Transient
from app.pipeline.process import process
from app.schemas import CreatedSave, CreateSave, ProcessTask

logging.basicConfig(level=logging.INFO)
app = FastAPI(title="Reelbrain API")
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
    save = store.get_save(save_id)
    # ponytail: owner-only until spaces/members exist (P1-03); then check uid in space members.
    if save is None or save.get("created_by") != uid:
        raise HTTPException(404, "save not found")
    return save


@app.post("/v1/saves", response_model=CreatedSave)
def create_save(body: CreateSave, uid: str = Depends(user)) -> CreatedSave:
    save_id = uuid.uuid4().hex
    store.create_save(
        save_id,
        {
            "source_url": body.source_url,
            "platform": platform(body.source_url),
            "space_id": body.space_id,
            "note": body.note,
            "caption": body.caption,
            "creator": body.creator,
            "status": "received",
            "step_text": None,
            "created_by": uid,
        },
    )
    return CreatedSave(save_id=save_id, upload_url=store.upload_url(save_id))


@app.post("/v1/saves/{save_id}/uploaded", status_code=202)
def uploaded(save_id: str, uid: str = Depends(user)) -> dict:
    save = owned_save(save_id, uid)
    store.update_save(save, {"status": "uploaded", "step_text": "Queued"})
    tasks.enqueue(save_id)
    return {"save_id": save_id}


@app.post("/v1/saves/{save_id}/retry", status_code=202)
def retry(save_id: str, uid: str = Depends(user)) -> dict:
    save = owned_save(save_id, uid)
    store.update_save(save, {"status": "received", "step_text": "Retrying"})
    tasks.enqueue(save_id)
    return {"save_id": save_id}


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
        if store.get_save(save_id) is None:
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
