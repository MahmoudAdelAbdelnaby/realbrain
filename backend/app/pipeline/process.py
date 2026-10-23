"""One save through the pipeline: video -> Extract -> key frame -> Firestore. Idempotent, safe to retry."""

import logging
import tempfile
import time
from pathlib import Path

from app import store
from app.pipeline import frames
from app.pipeline.extract import Transient, extract
from app.schemas import needs_review

log = logging.getLogger("reelbrain.process")
DONE = {"ready", "needs_review", "partial"}


def process(save_id: str, attempt: int = 0, max_attempts: int = 3) -> str:
    """Returns the final status. Raises Transient when the caller should retry later."""
    save = store.get_save(save_id)
    if save is None:
        raise LookupError(save_id)
    if save.get("status") in DONE:
        return save["status"]

    started = time.monotonic()
    with tempfile.TemporaryDirectory() as tmp:
        video = Path(tmp) / "video.mp4"
        try:
            if not store.fetch_video(save_id, video):
                raise RuntimeError("no video uploaded")
            store.update_save(save, {"status": "extracting", "step_text": "Watching the video"})
            meta = {"platform": save.get("platform"), "url": save.get("source_url")}
            result = extract(video, save.get("caption"), meta)

            frame_url = None
            if result.key_frame_t is not None:
                jpg = frames.key_frame(video, result.key_frame_t, Path(tmp) / "frame.jpg")
                if jpg:
                    frame_url = store.put_frame(save["space_id"], save_id, jpg)

            status = "needs_review" if needs_review(result) else "ready"
            store.put_items(save, [_item(s) for s in result.sections])
            store.update_save(
                save,
                {
                    "status": status,
                    "step_text": None,
                    "language": result.language,
                    "summary": result.summary,
                    "key_frame_url": frame_url,
                },
            )
            store.delete_video(save_id)
            log.info(
                "save=%s status=%s sections=%s in %.1fs",
                save_id,
                status,
                [s.type for s in result.sections],
                time.monotonic() - started,
            )
        except Transient as e:
            if attempt + 1 < max_attempts:
                store.update_save(
                    save,
                    {"step_text": f"Busy, retrying ({attempt + 1}/{max_attempts - 1})"},
                )
                log.warning("save=%s transient attempt=%d: %s", save_id, attempt, e)
                raise
            return _fail(save, str(e))
        except Exception as e:
            log.exception("save=%s failed", save_id)
            return _fail(save, str(e))
    return status


def _item(section) -> dict:
    return {
        "section": section.type,
        "confidence": section.confidence,
        "data": section.model_dump(exclude={"type", "confidence"}),
        "user_state": None,
    }


def _fail(save: dict, why: str) -> str:
    store.update_save(save, {"status": "failed", "step_text": why[:300]})
    store.delete_video(save["save_id"])
    return "failed"
