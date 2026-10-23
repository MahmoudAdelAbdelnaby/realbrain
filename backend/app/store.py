"""Documents (Firestore paths), videos and frames.

Documents: Firestore when USE_FIRESTORE=1 or GCS_BUCKET is set; otherwise JSON files under
DATA_DIR/docs laid out by the same paths, so tests and a laptop run need only a Gemini key.
Videos and frames: Cloud Storage when GCS_BUCKET is set; otherwise a folder under DATA_DIR
(served by the /dev routes). That split is the Spark-plan setup: Firestore results, videos on the PC.
"""

import json
import os
import shutil
import threading
import time
from datetime import timedelta
from pathlib import Path

BUCKET = os.environ.get("GCS_BUCKET")
FIRESTORE = bool(BUCKET) or os.environ.get("USE_FIRESTORE") == "1"
DATA = Path(os.environ.get("DATA_DIR", Path(__file__).resolve().parent.parent / "data"))
PUBLIC_URL = os.environ.get("PUBLIC_URL", "http://127.0.0.1:8000")
_lock = threading.RLock()


def _firestore():
    from firebase_admin import firestore

    from app.auth import firebase_app

    return firestore.client(firebase_app())


def _bucket():
    from firebase_admin import storage

    from app.auth import firebase_app

    return storage.bucket(BUCKET, firebase_app())


# --- documents ---


def _file(path: str) -> Path:
    parts = path.split("/")
    if any(p in ("", ".", "..") for p in parts):
        raise ValueError(f"bad path {path!r}")
    return DATA / "docs" / Path(*parts[:-1]) / f"{parts[-1]}.json"


def doc_get(path: str) -> dict | None:
    if FIRESTORE:
        snap = _firestore().document(path).get()
        return snap.to_dict() if snap.exists else None
    f = _file(path)
    return json.loads(f.read_text("utf-8")) if f.exists() else None


def doc_set(path: str, data: dict) -> None:
    if FIRESTORE:
        _firestore().document(path).set(data)
        return
    with _lock:
        f = _file(path)
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(json.dumps(data, ensure_ascii=False, indent=2), "utf-8")


def doc_update(path: str, fields: dict) -> None:
    if FIRESTORE:
        _firestore().document(path).update(fields)
        return
    with _lock:
        doc_set(path, {**(doc_get(path) or {}), **fields})


def doc_array_add(path: str, field: str, value) -> None:
    """Adds value to an array field if missing (Firestore ArrayUnion), safe with concurrent joins."""
    if FIRESTORE:
        from google.cloud.firestore import ArrayUnion

        _firestore().document(path).update({field: ArrayUnion([value])})
        return
    with _lock:
        data = doc_get(path) or {}
        if value not in data.get(field, []):
            doc_set(path, {**data, field: [*data.get(field, []), value]})


def col_list(path: str) -> list[dict]:
    if FIRESTORE:
        return [d.to_dict() for d in _firestore().collection(path).stream()]
    d = DATA / "docs" / Path(*path.split("/"))
    return [json.loads(f.read_text("utf-8")) for f in sorted(d.glob("*.json"))] if d.exists() else []


def col_replace(path: str, docs: dict[str, dict]) -> None:
    """Replaces every document in a collection (re-runs and retries stay idempotent)."""
    if FIRESTORE:
        db = _firestore()
        col = db.collection(path)
        batch = db.batch()
        for old in col.list_documents():
            batch.delete(old)
        for doc_id, data in docs.items():
            batch.set(col.document(doc_id), data)
        batch.commit()
        return
    with _lock:
        d = DATA / "docs" / Path(*path.split("/"))
        if d.exists():
            for f in d.glob("*.json"):
                f.unlink()
        for doc_id, data in docs.items():
            doc_set(f"{path}/{doc_id}", data)


# --- saves ---


def _save_path(save: dict) -> str:
    return f"spaces/{save['space_id']}/saves/{save['save_id']}"


def create_save(save_id: str, fields: dict) -> None:
    fields = {**fields, "save_id": save_id, "created_at": time.time()}
    doc_set(_save_path(fields), fields)
    # Endpoints only get the save id; this index finds its space without a collection-group query.
    doc_set(f"save_index/{save_id}", {"space_id": fields["space_id"], "created_by": fields["created_by"]})


def get_save(save_id: str) -> dict | None:
    index = doc_get(f"save_index/{save_id}")
    return doc_get(f"spaces/{index['space_id']}/saves/{save_id}") if index else None


def update_save(save: dict, fields: dict) -> None:
    """Every status change is written straight away so the processing card updates live."""
    save.update(fields)
    doc_update(_save_path(save), fields)


def put_items(save: dict, items: list[dict]) -> None:
    """One item per extracted section."""
    col_replace(_save_path(save) + "/items", {f"{i}-{item['section']}": item for i, item in enumerate(items)})


def get_items(save: dict) -> list[dict]:
    return col_list(_save_path(save) + "/items")


# --- videos (transient) and frames ---


def upload_url(save_id: str) -> str:
    """Where the phone PUTs the video. Signed GCS URL, valid 15 min; or this backend's /dev route."""
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
