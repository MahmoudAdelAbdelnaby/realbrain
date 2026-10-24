from fastapi.testclient import TestClient

from app import store
from app.main import app

client = TestClient(app)
ME = {"Authorization": "Bearer dev:retrier"}
BODY = {"source_url": "https://vt.tiktok.com/ZSgHje928/", "space_id": "me", "client_id": "264abee8-a5e9-47e6"}


def test_a_retried_share_gets_the_same_save_not_an_orphan():
    client.post("/v1/me", json={}, headers=ME)
    first = client.post("/v1/saves", json=BODY, headers=ME).json()
    again = client.post("/v1/saves", json=BODY, headers=ME).json()
    assert again["save_id"] == first["save_id"] and again["status"] == "received"
    assert client.get("/v1/settings", headers=ME).json()["saves_today"] == 1, "counted once"


def test_after_the_upload_went_through_a_retry_is_told_to_skip_it():
    first = client.post("/v1/saves", json={**BODY, "client_id": "second-share-0001"}, headers=ME).json()
    store.update_save(store.get_save(first["save_id"]), {"status": "uploaded"})
    again = client.post("/v1/saves", json={**BODY, "client_id": "second-share-0001"}, headers=ME).json()
    assert again["save_id"] == first["save_id"] and again["status"] == "uploaded"


def test_the_same_client_id_from_another_person_is_another_save():
    other = {"Authorization": "Bearer dev:someone-else"}
    client.post("/v1/me", json={}, headers=other)
    mine = client.post("/v1/saves", json=BODY, headers=ME).json()["save_id"]
    theirs = client.post("/v1/saves", json=BODY, headers=other).json()["save_id"]
    assert mine != theirs


def test_saves_without_a_client_id_still_work():
    a = client.post("/v1/saves", json={k: v for k, v in BODY.items() if k != "client_id"}, headers=ME).json()
    b = client.post("/v1/saves", json={k: v for k, v in BODY.items() if k != "client_id"}, headers=ME).json()
    assert a["save_id"] != b["save_id"]
