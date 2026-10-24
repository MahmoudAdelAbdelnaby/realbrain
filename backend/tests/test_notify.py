import json
from pathlib import Path

from fastapi.testclient import TestClient

from app import store
from app.main import app
from app.notify import key_line
from app.schemas import ExtractResult

SAMPLE = json.loads((Path(__file__).parent / "sample_extract.json").read_text("utf-8"))


def result(*sections, summary="Short summary."):
    return ExtractResult.model_validate({**SAMPLE, "summary": summary, "sections": list(sections)})


def test_key_line_uses_the_most_confident_section():
    by_type = {s["type"]: s for s in SAMPLE["sections"]}
    assert key_line(result(by_type["recipe"]))[0] == "Recipe ready: كشري"
    assert (
        key_line(result(by_type["places"], {**by_type["tools"], "confidence": 0.99}))[0] == "Tool saved: uv"
    )
    assert key_line(result(by_type["places"]))[0] == "Place saved: Abou Tarek, Downtown"
    assert key_line(result(by_type["workout"]))[0] == "Workout saved: 1 exercise"
    assert key_line(result(by_type["fact_check"]))[0] == "Fact check: 1 claim to check"
    assert key_line(result())[0] == "Saved, needs a look"
    assert key_line(result(by_type["recipe"]), partial=True)[0].startswith("Caption only · ")


def test_titles_fit_the_60_character_line_and_bodies_are_trimmed():
    long_tool = {"type": "tools", "confidence": 0.9, "items": [{"name": "x" * 100, "t": 1}]}
    title, body = key_line(result(long_tool, summary="word " * 100))
    assert len(title) <= 60 and title.endswith("…")
    assert len(body) <= 140


def test_me_registers_push_tokens_once():
    client = TestClient(app)
    auth = {"Authorization": "Bearer dev:pushy"}
    for _ in range(2):
        client.post("/v1/me", json={"fcm_token": "tok-1"}, headers=auth)
    client.post("/v1/me", json={"fcm_token": "tok-2"}, headers=auth)
    assert store.doc_get("users/pushy")["fcm_tokens"] == ["tok-1", "tok-2"]
