import json
from pathlib import Path

from app import store
from app.pipeline import process as process_mod
from app.schemas import ExtractResult
from tests.test_pipeline import AUTH, client, wait_status

SAMPLE = json.loads((Path(__file__).parent / "sample_extract.json").read_text("utf-8"))


def test_a_typed_idea_is_read_at_once_and_filed_as_an_idea(monkeypatch):
    seen = {}

    def fake_extract(video, caption, meta, video_uri=None, section_hint=None):
        seen.update(video=video, caption=caption, hint=section_hint)
        return ExtractResult.model_validate(
            {
                **SAMPLE,
                "sections": [
                    {
                        "type": "ideas",
                        "confidence": 0.9,
                        "title": "Meal-prep Sundays",
                        "idea": "Cook three bases on Sunday.",
                        "next_steps": ["Pick three recipes"],
                    }
                ],
            }
        )

    monkeypatch.setattr(process_mod, "extract", fake_extract)
    r = client.post("/v1/saves", json={"idea": "Meal prep on Sundays?", "space_id": "me"}, headers=AUTH)
    assert r.status_code == 200 and r.json()["status"] == "uploaded", "nothing to upload"
    save_id = r.json()["save_id"]
    assert wait_status(save_id) == "ready", "a typed idea is complete, not caption-only"
    assert seen == {"video": None, "caption": "Meal prep on Sundays?", "hint": "ideas"}
    save = store.get_save(save_id)
    assert save["platform"] == "idea" and save["fetch_path"] == "typed"
    assert [i["section"] for i in store.get_items(save)] == ["ideas"]


def test_create_sends_its_hint_and_needs_a_link_or_an_idea():
    r = client.post(
        "/v1/saves",
        json={"source_url": "https://vt.tiktok.com/x/", "space_id": "me", "section_hint": "recipe"},
        headers=AUTH,
    )
    assert store.get_save(r.json()["save_id"])["forced_section"] == "recipe"
    for bad in ({"space_id": "me"}, {"space_id": "me", "idea": "x", "source_url": "https://a.b/"}):
        assert client.post("/v1/saves", json=bad, headers=AUTH).status_code == 422
    assert (
        client.post(
            "/v1/saves", json={"idea": "x", "space_id": "me", "section_hint": "horoscope"}, headers=AUTH
        ).status_code
        == 422
    )
