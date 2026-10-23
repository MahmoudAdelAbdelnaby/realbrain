import pytest
from fastapi.testclient import TestClient

from app import store
from app.main import app
from app.pipeline import fetch
from app.pipeline import process as process_mod
from tests.test_pipeline import SAMPLE, wait_status

AUTH = {"Authorization": "Bearer dev"}
client = TestClient(app)


def boom(*_):
    raise RuntimeError("blocked from datacenter")


def test_parse_tikwm():
    body = {
        "code": 0,
        "data": {"play": "https://v.example/x.mp4", "title": "koshari", "author": {"nickname": "chef"}},
    }
    assert fetch.parse_tikwm(body) == ("https://v.example/x.mp4", "koshari", "chef")
    with pytest.raises(RuntimeError):
        fetch.parse_tikwm({"code": -1, "msg": "Url parsing is failed!"})


def test_chain_records_every_step_and_stops_at_first_success(monkeypatch, tmp_path):
    def mirror(save, dest):
        dest.write_bytes(b"mp4")
        return fetch.Fetched(path=dest, caption="from mirror")

    monkeypatch.setattr(
        fetch, "CHAIN", [("youtube", fetch.youtube_direct), ("mirror", mirror), ("yt-dlp", boom)]
    )
    got = fetch.fallback({"platform": "tiktok", "source_url": "https://vt.tiktok.com/a/"}, tmp_path / "v.mp4")
    assert got.used == "mirror" and got.caption == "from mirror"
    assert [(s["step"], s["ok"]) for s in got.steps] == [("youtube", False), ("mirror", True)]
    assert got.steps[0]["skipped"]


def test_youtube_goes_straight_to_gemini(tmp_path):
    got = fetch.fallback({"platform": "youtube", "source_url": "https://youtu.be/a"}, tmp_path / "v.mp4")
    assert got.used == "youtube" and got.uri == "https://youtu.be/a"


def _no_video_save(url: str, caption: str | None = None) -> str:
    body = {"source_url": url, "space_id": "home", "caption": caption}
    save_id = client.post("/v1/saves", json=body, headers=AUTH).json()["save_id"]
    assert (
        client.post(
            f"/v1/saves/{save_id}/no-video", json={"reason": "LOGIN_REQUIRED"}, headers=AUTH
        ).status_code
        == 202
    )
    return save_id


def test_everything_fails_but_caption_gives_a_partial_save(monkeypatch):
    seen = {}

    def fake_extract(video, caption, meta, video_uri=None):
        seen.update(video=video, uri=video_uri, caption=caption)
        return SAMPLE

    monkeypatch.setattr(
        fetch, "CHAIN", [("mirror", boom), ("yt-dlp", boom), ("caption", fetch.oembed_caption)]
    )
    monkeypatch.setattr(process_mod, "extract", fake_extract)
    save_id = _no_video_save("https://www.instagram.com/reel/b/", caption="best koshari in Cairo")
    assert wait_status(save_id) == "partial"
    save = store.get_save(save_id)
    assert seen == {"video": None, "uri": None, "caption": "best koshari in Cairo"}
    assert save["fetch_path"] == "caption" and save["summary"] and save["no_video_reason"] == "LOGIN_REQUIRED"
    assert [s["step"] for s in save["fetch_steps"]] == ["mirror", "yt-dlp", "caption"]
    assert save["key_frame_url"] is None


def test_nothing_at_all_fails(monkeypatch):
    monkeypatch.setattr(fetch, "CHAIN", [("mirror", boom), ("caption", fetch.oembed_caption)])
    monkeypatch.setattr(process_mod, "extract", lambda *a, **k: SAMPLE)
    save_id = _no_video_save("https://www.instagram.com/reel/c/")
    assert wait_status(save_id) == "failed"
    assert "no video or caption" in store.get_save(save_id)["step_text"]
