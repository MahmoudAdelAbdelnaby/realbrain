import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app import store, tasks
from app.main import app
from app.pipeline import process as process_mod
from app.schemas import ExtractResult

SAMPLE = json.loads((Path(__file__).parent / "sample_extract.json").read_text("utf-8"))
RECIPE = next(s for s in SAMPLE["sections"] if s["type"] == "recipe")
AUTH = {"Authorization": "Bearer dev:inbox"}
TASKS = {"Authorization": "Bearer dev"}  # what Cloud Tasks presents to /internal
client = TestClient(app)


@pytest.fixture
def calls(monkeypatch):
    """Extract returns nothing unless the user filed it as a recipe; records each call's hint."""
    seen = []

    def fake_extract(video, caption, meta, video_uri=None, section_hint=None):
        seen.append({"hint": section_hint, "video": video is not None})
        sections = [RECIPE] if section_hint == "recipe" else []
        return ExtractResult.model_validate({**SAMPLE, "sections": sections, "key_frame_t": None})

    monkeypatch.setattr(process_mod, "extract", fake_extract)
    monkeypatch.setattr(tasks, "enqueue", lambda save_id: None)  # run /internal/process by hand
    return seen


def _review_save() -> str:
    save_id = client.post(
        "/v1/saves", json={"source_url": "https://youtu.be/k", "space_id": "me"}, headers=AUTH
    ).json()["save_id"]
    store.local_video(save_id).write_bytes(b"video bytes")
    assert (
        client.post("/internal/process", json={"save_id": save_id}, headers=TASKS).json()["status"]
        == "needs_review"
    )
    return save_id


def test_filing_a_review_save_rereads_the_kept_video_with_the_hint(calls):
    save_id = _review_save()
    assert store.local_video(save_id).exists(), "kept while it needs review"

    r = client.post(f"/v1/saves/{save_id}/section", json={"section": "recipe"}, headers=AUTH)
    assert r.status_code == 200
    assert store.get_save(save_id)["status"] == "received"
    assert (
        client.post("/internal/process", json={"save_id": save_id}, headers=TASKS).json()["status"] == "ready"
    )

    assert calls == [{"hint": None, "video": True}, {"hint": "recipe", "video": True}]
    save = store.get_save(save_id)
    assert save["sections"] == ["recipe"] and save["forced_section"] == "recipe"
    assert [i["section"] for i in store.get_items(save)] == ["recipe"]
    assert not store.local_video(save_id).exists(), "deleted once it resolves"
    logged = [c for c in store.col_list("corrections") if c["save_id"] == save_id]
    assert logged and logged[0]["to_section"] == "recipe" and logged[0]["from_status"] == "needs_review"


def test_a_hint_the_video_cannot_support_stays_in_review(calls):
    save_id = _review_save()
    client.post(f"/v1/saves/{save_id}/section", json={"section": "workout"}, headers=AUTH)
    assert (
        client.post("/internal/process", json={"save_id": save_id}, headers=TASKS).json()["status"]
        == "needs_review"
    )


def test_section_rejects_unknown_sections_and_strangers(calls):
    save_id = _review_save()
    bad = client.post(f"/v1/saves/{save_id}/section", json={"section": "horoscope"}, headers=AUTH)
    assert bad.status_code == 422
    stranger = {"Authorization": "Bearer dev:someone-else"}
    assert (
        client.post(f"/v1/saves/{save_id}/section", json={"section": "recipe"}, headers=stranger).status_code
        == 404
    )


def test_retry_runs_a_failed_save_again(calls, monkeypatch):
    save_id = _review_save()
    store.update_save(store.get_save(save_id), {"status": "failed", "step_text": "boom"})
    assert client.post(f"/v1/saves/{save_id}/retry", headers=AUTH).status_code == 202
    assert store.get_save(save_id)["status"] == "received"
    assert (
        client.post("/internal/process", json={"save_id": save_id}, headers=TASKS).json()["status"]
        == "needs_review"
    )
