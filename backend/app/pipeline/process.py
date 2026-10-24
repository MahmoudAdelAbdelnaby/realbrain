"""One save through the pipeline: video -> Extract -> key frame -> Firestore. Idempotent, safe to retry."""

import logging
import os
import tempfile
import time
from pathlib import Path

from app import notify, store
from app.pipeline import enrich, frames, tools
from app.pipeline.extract import Transient, extract
from app.pipeline.fetch import fallback
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
        video: Path | None = Path(tmp) / "video.mp4"
        try:
            uri, caption, fetch = None, save.get("caption"), {"fetch_path": "phone"}
            if not store.fetch_video(save_id, video):
                store.update_save(save, {"status": "fetching", "step_text": "Getting the video"})
                got = fallback(save, video)
                video, uri, caption = got.path, got.uri, got.caption
                fetch = {"fetch_path": got.used, "fetch_steps": got.steps}
                if got.creator and not save.get("creator"):
                    fetch["creator"] = got.creator
                if got.used == "none":
                    raise RuntimeError("no video or caption from any source")
            caption_only = video is None and uri is None
            store.update_save(
                save,
                {**fetch, "caption": caption, "status": "extracting", "step_text": "Watching the video"},
            )
            meta = {
                "platform": save.get("platform"),
                "url": save.get("source_url"),
                "creator": save.get("creator"),
            }
            hint = save.get("forced_section")  # P1-07: the user filed it under this section
            t0 = time.monotonic()
            result = extract(video, caption, meta, video_uri=uri, **({"section_hint": hint} if hint else {}))
            extract_ms = int((time.monotonic() - t0) * 1000)

            frame_url = None
            if video is not None and result.key_frame_t is not None:
                jpg = frames.key_frame(video, result.key_frame_t, Path(tmp) / "frame.jpg")
                if jpg:
                    frame_url = store.put_frame(save["space_id"], save_id, jpg)

            if hint:  # the user's choice beats the confidence bar
                status = "ready" if any(s.type == hint for s in result.sections) else "needs_review"
            else:
                status = "needs_review" if needs_review(result) else "ready"
            if caption_only:
                status = "partial"
            items = [_item(s) for s in result.sections]
            _verify_tools(items)
            verdict = _check_claims(save, items, result.language) if status in ("ready", "partial") else None
            store.put_items(save, items)
            store.update_save(
                save,
                {
                    "status": status,
                    "verdict": verdict and verdict["overall"],  # feed card, P1-08
                    "step_text": None,
                    "language": result.language,
                    "summary": result.summary,
                    "sections": [s.type for s in result.sections],  # feed card chips without reading items
                    "key_frame_url": frame_url,
                    "extract_ms": extract_ms,  # spike report (P0-07)
                },
            )
            # Kept while it needs review, so filing it re-reads the real video; gone once it resolves.
            if status != "needs_review":
                store.delete_video(save_id)
            if status in ("ready", "partial"):
                notify.send(
                    save, result, partial=status == "partial", title=verdict and verdict["notification"]
                )
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


def _verify_tools(items: list[dict]) -> None:
    """P1-09: check tool links (and GitHub repos) before the save lands."""
    if os.environ.get("VERIFY_TOOLS", "1") != "1":
        return
    for item in items:
        if item["section"] == "tools" and item["data"].get("items"):
            item["data"]["items"] = tools.verify(item["data"]["items"])


def _check_claims(save: dict, items: list[dict], language: str | None) -> dict | None:
    """P1-08: ground the Fact Check claims. A failure leaves them unchecked; the save still lands."""
    fact = next((i for i in items if i["section"] == "fact_check" and i["data"].get("claims")), None)
    if fact is None:
        return None
    store.update_save(save, {"status": "enriching", "step_text": "Checking the claims"})
    try:
        fact["data"].update(enrich.check(fact["data"]["claims"], language))
        return fact["data"]
    except Exception as e:  # noqa: BLE001 - grounding is a bonus on top of a finished save
        log.warning("save=%s fact check failed: %s", save["save_id"], e)
        fact["data"]["check_error"] = str(e)[:200]
        return None


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
