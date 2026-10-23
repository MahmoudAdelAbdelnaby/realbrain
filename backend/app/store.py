"""Saves, videos and frames.

Cloud (GCS_BUCKET set): Firestore + Cloud Storage, as in the Backend contract.
Local (default): JSON files and a folder under DATA_DIR, so the pipeline runs with only a Gemini key.
"""

import json
import os
import shutil
import threading
import time
from datetime import timedelta
from pathlib import Path

BUCKET = os.environ.get("GCS_BUCKET")
DATA = Path(os.environ.get("DATA_DIR", Path(__file__).resolve().parent.parent / "data"))
PUBLIC_URL = os.environ.get("PUBLIC_URL", "http://127.0.0.1:8000")
_lock = threading.Lock()


def _firestore():
    from firebase_admin import firestore

    from app.auth import firebase_app

    return firestore.client(firebase_app())


def _bucket():
    from firebase_admin import storage

    from app.auth import firebase_app

    return storage.bucket(BUCKET, firebase_app())


# --- saves ---


def create_save(save_id: str, fields: dict) -> None:
    fields = {**fields, "save_id": save_id, "created_at": time.time()}
    if BUCKET:
        db = _firestore()
        db.document(f"spaces/{fields['space_id']}/saves/{save_id}").set(fields)
        # Endpoints only get the save id; this index finds its space without a collection-group query.
        db.document(f"save_index/{save_id}").set(
            {"space_id": fields["space_id"], "created_by": fields["created_by"]}
        )
        return
    with _lock:
        _local_path(save_id).write_text(
            json.dumps({**fields, "items": []}, ensure_ascii=False, indent=2), "utf-8"
        )


def get_save(save_id: str) -> dict | None:
    if BUCKET:
        db = _firestore()
        index = db.document(f"save_index/{save_id}").get()
        if not index.exists:
            return None
        doc = db.document(f"spaces/{index.get('space_id')}/saves/{save_id}").get()
        return doc.to_dict() if doc.exists else None
    p = _local_path(save_id)
    return json.loads(p.read_text("utf-8")) if p.exists() else None


def update_save(save: dict, fields: dict) -> None:
    """Every status change is written straight away so the processing card updates live."""
    save.update(fields)
    if BUCKET:
        _firestore().document(f"spaces/{save['space_id']}/saves/{save['save_id']}").update(fields)
        return
    with _lock:
        p = _local_path(save["save_id"])
        data = json.loads(p.read_text("utf-8"))
        data.update(fields)
        p.write_text(json.dumps(data, ensure_ascii=False, indent=2), "utf-8")


def put_items(save: dict, items: list[dict]) -> None:
    """One item per extracted section, replacing earlier ones (re-runs and retries are idempotent)."""
    if BUCKET:
        db = _firestore()
        col = db.collection(f"spaces/{save['space_id']}/saves/{save['save_id']}/items")
        batch = db.batch()
        for old in col.list_documents():
            batch.delete(old)
        for i, item in enumerate(items):
            batch.set(col.document(f"{i}-{item['section']}"), item)
        batch.commit()
        return
    update_save(save, {"items": items})


def _local_path(save_id: str) -> Path:
    d = DATA / "saves"
    d.mkdir(parents=True, exist_ok=True)
    return d / f"{Path(save_id).name}.json"


# --- videos (transient) and frames ---


def upload_url(save_id: str) -> str:
    """Where the phone PUTs the video. Signed GCS URL, valid 15 min."""
    if BUCKET:
        import google.auth
        from google.auth.transport.requests import Request

        creds, _ = google.auth.default()
        creds.refresh(Request())
        return (
            _bucket()
            .blob(f"videos/{save_id}.mp4")
            .generate_signed_url(
                version="v4",
                expiration=timedelta(minutes=15),
                method="PUT",
                content_type="video/mp4",
                # Cloud Run has no key file: sign through IAM with the service account's token.
                service_account_email=getattr(creds, "service_account_email", None),
                access_token=creds.token,
            )
        )
    return f"{PUBLIC_URL}/dev/uploads/{save_id}"


def local_video(save_id: str) -> Path:
    d = DATA / "videos"
    d.mkdir(parents=True, exist_ok=True)
    return d / f"{Path(save_id).name}.mp4"


def fetch_video(save_id: str, dest: Path) -> bool:
    """Copies the uploaded video to dest; False if nothing was uploaded."""
    if BUCKET:
        blob = _bucket().blob(f"videos/{save_id}.mp4")
        if not blob.exists():
            return False
        blob.download_to_filename(dest)
        return True
    src = local_video(save_id)
    if not src.exists():
        return False
    shutil.copyfile(src, dest)
    return True


def delete_video(save_id: str) -> None:
    if BUCKET:
        blob = _bucket().blob(f"videos/{save_id}.mp4")
        if blob.exists():
            blob.delete()
        return
    local_video(save_id).unlink(missing_ok=True)


def put_frame(space_id: str, save_id: str, jpg: Path) -> str:
    if BUCKET:
        blob = _bucket().blob(f"frames/{space_id}/{save_id}.jpg")
        blob.upload_from_filename(jpg, content_type="image/jpeg")
        return f"gs://{BUCKET}/{blob.name}"
    d = DATA / "frames" / Path(space_id).name
    d.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(jpg, d / f"{save_id}.jpg")
    return f"{PUBLIC_URL}/dev/frames/{space_id}/{save_id}.jpg"
