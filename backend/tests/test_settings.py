from fastapi.testclient import TestClient

from app import store, usage
from app.main import app

client = TestClient(app)


def test_saves_are_counted_without_a_cap():
    me = {"Authorization": "Bearer dev:counted"}
    client.post("/v1/me", json={}, headers=me)
    body = {"source_url": "https://youtu.be/a", "space_id": "me"}
    for _ in range(25):
        assert client.post("/v1/saves", json=body, headers=me).status_code == 200
    assert client.get("/v1/settings", headers=me).json()["saves_today"] == 25


def test_yesterdays_count_does_not_carry_over():
    me = {"Authorization": "Bearer dev:newday"}
    client.post("/v1/me", json={}, headers=me)
    store.doc_update("users/newday", {"saves_today": {"date": "2000-01-01", "count": 99}})
    body = {"source_url": "https://youtu.be/a", "space_id": "me"}
    assert client.post("/v1/saves", json=body, headers=me).status_code == 200
    assert client.get("/v1/settings", headers=me).json()["saves_today"] == 1


def test_settings_report_usage_and_models():
    me = {"Authorization": "Bearer dev:settings"}
    client.patch("/v1/settings", json={"theme": "dark", "lang": "ar"}, headers=me)
    usage.count_model("gemini-3.6-flash")
    s = client.get("/v1/settings", headers=me).json()
    assert s["settings"] == {"lang": "ar", "theme": "dark", "recall": True, "puzzle": True}
    flash = next(m for m in s["gemini"]["usage_today"] if m["model"] == "gemini-3.6-flash")
    assert flash["used"] >= 1 and flash["free_per_day"] == 20
    assert s["billing"].startswith("Spark")


def test_bad_settings_are_rejected():
    me = {"Authorization": "Bearer dev:settings"}
    assert client.patch("/v1/settings", json={"theme": "purple"}, headers=me).status_code == 422
