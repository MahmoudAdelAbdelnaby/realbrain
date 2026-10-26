from fastapi.testclient import TestClient

from app import store
from app.main import app

client = TestClient(app)
ME = {"Authorization": "Bearer dev:shortcut-user"}
REEL = "https://www.instagram.com/reel/DAbc123/"


def _key() -> str:
    client.post("/v1/me", json={}, headers=ME)
    return client.post("/v1/me/save-key", headers=ME).json()["key"]


def test_a_good_key_saves_the_link_and_the_backend_fetches_it():
    key = _key()
    r = client.post("/v1/shortcut/save", json={"url": f"Look at this {REEL}"}, headers={"X-Save-Key": key})
    assert r.status_code == 202
    save = store.get_save(r.json()["save_id"])
    assert save["source_url"] == REEL and save["created_by"] == "shortcut-user"
    assert save["status"] != "received", "handed to the backend's fetch"


def test_a_double_tap_is_one_save():
    key = _key()
    url = {"url": "https://vt.tiktok.com/ZSdouble/"}
    a = client.post("/v1/shortcut/save", json=url, headers={"X-Save-Key": key}).json()
    b = client.post("/v1/shortcut/save", json=url, headers={"X-Save-Key": key}).json()
    assert a["save_id"] == b["save_id"]


def test_a_bad_or_replaced_key_is_refused():
    old = _key()
    new = client.post("/v1/me/save-key", headers=ME).json()["key"]
    body = {"url": REEL}
    assert client.post("/v1/shortcut/save", json=body, headers={"X-Save-Key": "nope"}).status_code == 401
    assert client.post("/v1/shortcut/save", json=body).status_code == 401
    assert client.post("/v1/shortcut/save", json=body, headers={"X-Save-Key": old}).status_code == 401
    assert client.post("/v1/shortcut/save", json=body, headers={"X-Save-Key": new}).status_code == 202
