import json
from pathlib import Path
from types import SimpleNamespace as NS

import pytest
from fastapi.testclient import TestClient

from app import notify, store, tasks
from app.main import app
from app.pipeline import enrich
from app.pipeline import process as process_mod
from app.schemas import ExtractResult

SAMPLE = json.loads((Path(__file__).parent / "sample_extract.json").read_text("utf-8"))
FACT = {
    "type": "fact_check",
    "confidence": 0.9,
    "claims": [
        {"text": "Lemon water detoxes the liver", "t": 3},
        {"text": "Lemons contain vitamin C", "t": 9},
    ],
}
AUTH = {"Authorization": "Bearer dev:facts"}
TASKS = {"Authorization": "Bearer dev"}
client = TestClient(app)


def grounded_reply(payload: dict | str, urls=("https://who.int/a", "https://nih.gov/b"), queries=None):
    text = payload if isinstance(payload, str) else "Here you go:\n```json\n" + json.dumps(payload) + "\n```"
    chunks = [NS(web=NS(uri=u, title=u.split("/")[2])) for u in urls]
    meta = NS(grounding_chunks=chunks, web_search_queries=queries)
    return NS(text=text, candidates=[NS(grounding_metadata=meta)])


VERDICTS = {
    "claims": [
        {"verdict": "false", "correction": "The liver and kidneys clear toxins; lemon water doesn't."},
        {"verdict": "true", "correction": None},
    ],
    "overall": "mostly_false",
    "notification": "Mostly false: lemon water doesn't detox your liver, it's just water with lemon in it",
}


def test_check_merges_verdicts_sources_and_caps_the_line(monkeypatch):
    monkeypatch.setattr(enrich, "_grounded", lambda prompt: grounded_reply(VERDICTS))
    out = enrich.check(FACT["claims"], "en-US")
    assert [c["verdict"] for c in out["claims"]] == ["false", "true"]
    assert out["claims"][0]["t"] == 3 and out["claims"][0]["correction"].startswith("The liver")
    assert out["overall"] == "mostly_false" and len(out["notification"]) <= 60
    assert out["notification"].endswith("…") and not out["notification"][:-1].endswith(" ")
    assert [s["url"] for s in out["sources"]] == ["https://who.int/a", "https://nih.gov/b"]
    assert out["ai_generated"] is True and out["checked_at"] > 0


def test_searches_become_sources_when_the_reply_has_no_citations(monkeypatch):
    reply = grounded_reply(VERDICTS, urls=(), queries=["does lemon water detox liver"])
    monkeypatch.setattr(enrich, "_grounded", lambda prompt: reply)
    out = enrich.check(FACT["claims"], "en-US")
    assert out["sources"] == [
        {
            "title": "Search: does lemon water detox liver",
            "url": "https://www.google.com/search?q=does+lemon+water+detox+liver",
        }
    ]


def test_unreadable_reply_is_an_error(monkeypatch):
    monkeypatch.setattr(enrich, "_grounded", lambda prompt: grounded_reply("I couldn't find anything."))
    with pytest.raises(ValueError):
        enrich.check(FACT["claims"], "en-US")


@pytest.fixture
def fact_save(monkeypatch):
    monkeypatch.setattr(
        process_mod,
        "extract",
        lambda *a, **k: ExtractResult.model_validate({**SAMPLE, "sections": [FACT], "key_frame_t": None}),
    )
    monkeypatch.setattr(tasks, "enqueue", lambda save_id: None)
    sent = []
    monkeypatch.setattr(notify, "send", lambda save, result, partial=False, title=None: sent.append(title))
    save_id = client.post(
        "/v1/saves", json={"source_url": "https://youtu.be/f", "space_id": "me"}, headers=AUTH
    ).json()["save_id"]
    store.local_video(save_id).write_bytes(b"video")
    return save_id, sent


def test_a_fact_check_save_is_grounded_and_notifies_with_the_verdict(fact_save, monkeypatch):
    save_id, sent = fact_save
    monkeypatch.setattr(enrich, "_grounded", lambda prompt: grounded_reply(VERDICTS))
    assert (
        client.post("/internal/process", json={"save_id": save_id}, headers=TASKS).json()["status"] == "ready"
    )
    save = store.get_save(save_id)
    item = store.get_items(save)[0]
    assert save["verdict"] == "mostly_false"
    assert item["data"]["claims"][0]["verdict"] == "false" and item["data"]["sources"]
    assert sent == [enrich._line(VERDICTS["notification"])]


def test_grounding_failure_still_lands_the_save(fact_save, monkeypatch):
    save_id, sent = fact_save

    def busy(prompt):
        raise enrich.Transient("grounding busy")

    monkeypatch.setattr(enrich, "_grounded", busy)
    assert (
        client.post("/internal/process", json={"save_id": save_id}, headers=TASKS).json()["status"] == "ready"
    )
    item = store.get_items(store.get_save(save_id))[0]
    assert "check_error" in item["data"] and "verdict" not in item["data"]["claims"][0]
    assert sent == [None], "falls back to the extract-based title"


def test_deep_dive_writes_an_explainer_and_checks_unchecked_claims(fact_save, monkeypatch):
    save_id, _ = fact_save
    monkeypatch.setattr(enrich, "_grounded", lambda prompt: (_ for _ in ()).throw(enrich.Transient("busy")))
    client.post("/internal/process", json={"save_id": save_id}, headers=TASKS)

    def answer(prompt):
        if "Reply with JSON only" in prompt:
            return grounded_reply(VERDICTS)
        return grounded_reply("Lemon water is fine to drink, but your liver does the detoxing.")

    monkeypatch.setattr(enrich, "_grounded", answer)
    assert client.post(f"/v1/saves/{save_id}/deep-dive", headers=AUTH).status_code == 202
    data = store.get_items(store.get_save(save_id))[0]["data"]
    assert data["explainer"].startswith("Lemon water") and data["explainer_sources"]
    assert data["claims"][0]["verdict"] == "false"
    assert (
        client.post(f"/v1/saves/{save_id}/deep-dive", headers={"Authorization": "Bearer dev:x"}).status_code
        == 404
    )
