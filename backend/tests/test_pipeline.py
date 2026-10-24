import shutil
import subprocess
import time
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app import store
from app.main import app, platform
from app.pipeline import process as process_mod
from app.pipeline.extract import Transient
from app.schemas import ExtractResult

SAMPLE = ExtractResult.model_validate_json((Path(__file__).parent / "sample_extract.json").read_text("utf-8"))
AUTH = {"Authorization": "Bearer dev"}
client = TestClient(app)
needs_ffmpeg = pytest.mark.skipif(shutil.which("ffmpeg") is None, reason="ffmpeg not installed")


@pytest.fixture
def tiny_mp4(tmp_path) -> bytes:
    out = tmp_path / "v.mp4"
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-loglevel",
            "error",
            "-f",
            "lavfi",
            "-i",
            "testsrc=size=160x120:rate=10:duration=1",
            "-pix_fmt",
            "yuv420p",
            str(out),
        ],
        check=True,
    )
    return out.read_bytes()


def wait_status(save_id: str, timeout: float = 10) -> str:
    end = time.time() + timeout
    while time.time() < end:
        status = store.get_save(save_id)["status"]
        if status in ("ready", "needs_review", "partial", "failed"):
            return status
        time.sleep(0.05)
    raise TimeoutError(status)


def test_requires_token():
    assert (
        client.post("/v1/saves", json={"source_url": "https://x.com/a", "space_id": "me"}).status_code == 401
    )
    bad = {"Authorization": "Bearer nope"}
    assert (
        client.post(
            "/v1/saves",
            json={"source_url": "https://x.com/a", "space_id": "me"},
            headers=bad,
        ).status_code
        == 401
    )


def test_platform_detection():
    assert platform("https://vt.tiktok.com/ZSg/") == "tiktok"
    assert platform("https://www.instagram.com/reel/abc/") == "instagram"
    assert platform("https://youtu.be/abc") == "youtube"
    assert platform("https://eviltiktok.com/x") == "other"


@needs_ffmpeg
def test_save_upload_process_ready(monkeypatch, tiny_mp4):
    seen = {}

    def fake_extract(video, caption, meta, video_uri=None, **_):
        seen.update(video_exists=video.exists(), caption=caption, meta=meta)
        return SAMPLE

    monkeypatch.setattr(process_mod, "extract", fake_extract)
    r = client.post(
        "/v1/saves",
        json={
            "source_url": "https://vt.tiktok.com/ZSg/",
            "space_id": "me",
            "caption": "koshari #recipe",
        },
        headers=AUTH,
    )
    assert r.status_code == 200
    save_id, upload_url = r.json()["save_id"], r.json()["upload_url"]
    assert upload_url.endswith(f"/dev/uploads/{save_id}")

    assert client.put(f"/dev/uploads/{save_id}", content=tiny_mp4).json()["bytes"] == len(tiny_mp4)
    assert client.post(f"/v1/saves/{save_id}/uploaded", headers=AUTH).status_code == 202
    assert wait_status(save_id) == "ready"

    save = store.get_save(save_id)
    assert seen == {
        "video_exists": True,
        "caption": "koshari #recipe",
        "meta": {"platform": "tiktok", "url": "https://vt.tiktok.com/ZSg/", "creator": None},
    }
    assert save["language"] == "ar-EG" and save["summary"]
    items = store.get_items(save)
    assert [i["section"] for i in items] == ["fact_check", "tools", "recipe", "places", "workout"]
    assert items[2]["data"]["steps"][0]["timer_s"] == 600
    assert {i["space_id"] for i in items} == {"p_dev"} and items[0]["save_id"] == save_id
    assert save["sections"] == ["fact_check", "tools", "recipe", "places", "workout"]
    assert save["space_id"] == "p_dev", "share target 'me' resolves to the personal space"
    frame = store.DATA / "frames" / "p_dev" / f"{save_id}.jpg"
    assert frame.stat().st_size > 0 and client.get(save["key_frame_url"]).status_code == 200
    assert not store.local_video(save_id).exists(), "video must be deleted when the job ends"


def test_non_members_cannot_touch_a_save():
    r = client.post("/v1/saves", json={"source_url": "https://youtu.be/a", "space_id": "me"}, headers=AUTH)
    save_id = r.json()["save_id"]
    stranger = {"Authorization": "Bearer dev:stranger"}
    assert client.post(f"/v1/saves/{save_id}/uploaded", headers=stranger).status_code == 404
    assert client.post(f"/v1/saves/{save_id}/uploaded", headers=AUTH).status_code == 202


def _uploaded_save() -> str:
    save_id = client.post(
        "/v1/saves",
        json={"source_url": "https://youtu.be/a", "space_id": "me"},
        headers=AUTH,
    ).json()["save_id"]
    store.local_video(save_id).write_bytes(b"not really a video")
    return save_id


def test_transient_errors_retry_then_fail(monkeypatch):
    def busy(*a, **k):
        raise Transient("Gemini 429")

    monkeypatch.setattr(process_mod, "extract", busy)
    save_id = _uploaded_save()
    for attempt in (0, 1):
        r = client.post(
            "/internal/process",
            json={"save_id": save_id},
            headers={**AUTH, "X-CloudTasks-TaskRetryCount": str(attempt)},
        )
        assert r.status_code == 503
        assert store.get_save(save_id)["status"] != "failed"
    r = client.post(
        "/internal/process",
        json={"save_id": save_id},
        headers={**AUTH, "X-CloudTasks-TaskRetryCount": "2"},
    )
    assert r.status_code == 200 and r.json()["status"] == "failed"


def test_low_confidence_goes_to_review(monkeypatch):
    low = SAMPLE.model_copy(update={"sections": [], "key_frame_t": None})
    monkeypatch.setattr(process_mod, "extract", lambda *a, **k: low)
    save_id = _uploaded_save()
    assert (
        client.post("/internal/process", json={"save_id": save_id}, headers=AUTH).json()["status"]
        == "needs_review"
    )


def test_extract_tries_every_model_then_the_next_key(monkeypatch):
    from google.genai import errors

    from app.pipeline import extract as ex

    calls = []

    def fake_client(key):
        class Models:
            def generate_content(self, model, contents, config):
                calls.append((key, model))
                if (key, model) != ("wife", "flash"):
                    raise errors.APIError(503, {"error": {"message": "high demand"}})
                return type("R", (), {"text": SAMPLE.model_dump_json()})()

        return type("C", (), {"models": Models()})()

    monkeypatch.setenv("GEMINI_API_KEYS", "mine, wife")
    monkeypatch.setattr(ex, "MODELS", ["flash", "lite"])
    monkeypatch.setattr(ex, "client", fake_client)
    assert ex.extract(None, "caption", {}).language == "ar-EG"
    assert calls == [("mine", "flash"), ("mine", "lite"), ("wife", "flash")]

    monkeypatch.setenv("GEMINI_API_KEYS", "mine")
    with pytest.raises(Transient, match="key1 flash 503, key1 lite 503"):
        ex.extract(None, "caption", {})


def test_gemini_calls_are_spaced(monkeypatch):
    from app.pipeline import extract as ex

    clock = {"t": 100.0}
    slept = []
    monkeypatch.setattr(ex, "MIN_GAP_S", 15)
    monkeypatch.setattr(ex, "_last_call", 0.0)
    monkeypatch.setattr(ex.time, "monotonic", lambda: clock["t"])

    def sleep(s):
        slept.append(round(s))
        clock["t"] += s

    monkeypatch.setattr(ex.time, "sleep", sleep)
    ex._pace()  # first call goes straight out
    clock["t"] += 4
    ex._pace()  # 4 s later: waits the remaining 11 s
    assert slept == [11]
