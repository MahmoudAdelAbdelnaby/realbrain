import time

from fastapi.testclient import TestClient

from app import store
from app.main import app

client = TestClient(app)
ME = {"Authorization": "Bearer dev:mahmoud"}
WIFE = {"Authorization": "Bearer dev:wife"}
STRANGER = {"Authorization": "Bearer dev:stranger"}


def test_first_call_creates_user_and_personal_space_once():
    r = client.post("/v1/me", json={"name": "Mahmoud", "lang": "ar"}, headers=ME).json()
    assert r == {"uid": "mahmoud", "spaces": {"me": "p_mahmoud"}}
    assert store.doc_get("spaces/p_mahmoud")["members"] == ["mahmoud"]
    assert store.doc_get("users/mahmoud")["lang"] == "ar"
    assert client.post("/v1/me", json={}, headers=ME).json()["spaces"] == {"me": "p_mahmoud"}


def test_household_invite_join_and_home_share():
    created = client.post("/v1/spaces/household", json={"name": "Home"}, headers=ME).json()
    home, url = created["space_id"], created["invite_url"]
    assert url.startswith("https://reelbrain-dev.web.app/join/")
    code = url.rsplit("/", 1)[1]
    assert len(code) == 8

    # A second "create" returns the same household with a fresh link.
    again = client.post("/v1/spaces/household", json={"name": "Home"}, headers=ME).json()
    assert again["space_id"] == home and again["invite_url"] != url

    assert client.post(f"/v1/invites/{code.upper()}/accept", headers=WIFE).json() == {"space_id": home}
    assert client.post(f"/v1/invites/{code}/accept", headers=WIFE).status_code == 200  # idempotent
    assert store.doc_get(f"spaces/{home}")["members"] == ["mahmoud", "wife"]
    assert store.doc_get("users/wife")["spaces"] == {"me": "p_wife", "home": home}

    # Her "Home" share lands in the shared space, and both of you can act on it.
    save_id = client.post(
        "/v1/saves", json={"source_url": "https://youtu.be/a", "space_id": "home"}, headers=WIFE
    ).json()["save_id"]
    assert store.get_save(save_id)["space_id"] == home
    assert client.post(f"/v1/saves/{save_id}/retry", headers=ME).status_code == 202
    assert client.post(f"/v1/saves/{save_id}/retry", headers=STRANGER).status_code == 404


def test_bad_or_expired_invites_and_no_sharing_personal():
    assert client.post("/v1/invites/nope2345/accept", headers=STRANGER).status_code == 404
    assert client.post("/v1/invites/..%2Fx/accept", headers=STRANGER).status_code == 404
    store.doc_set(
        "invites/old23456", {"space_id": "h_x", "created_by": "mahmoud", "expires_at": time.time() - 1}
    )
    assert client.post("/v1/invites/old23456/accept", headers=STRANGER).status_code == 410
    client.post("/v1/me", json={}, headers=STRANGER)
    assert client.post("/v1/spaces/p_stranger/invite", headers=STRANGER).status_code == 400
    assert client.post("/v1/spaces/p_mahmoud/invite", headers=STRANGER).status_code == 404


def test_cannot_save_into_someone_elses_space():
    r = client.post(
        "/v1/saves", json={"source_url": "https://youtu.be/a", "space_id": "p_mahmoud"}, headers=STRANGER
    )
    assert r.status_code == 404


def test_home_without_household_falls_back_to_personal():
    save_id = client.post(
        "/v1/saves", json={"source_url": "https://youtu.be/a", "space_id": "home"}, headers=STRANGER
    ).json()["save_id"]
    assert store.get_save(save_id)["space_id"] == "p_stranger"


def test_missing_name_is_filled_in_later():
    first = {"Authorization": "Bearer dev:late-name"}
    client.post("/v1/me", json={}, headers=first)
    client.post("/v1/me", json={"name": "Sara"}, headers=first)
    assert store.doc_get("users/late-name")["name"] == "Sara"


def test_lists_are_created_in_your_space_only():
    me = {"Authorization": "Bearer dev:lister"}
    r = client.post("/v1/spaces/me/lists", json={"section": "workout", "name": "Morning"}, headers=me).json()
    lst = store.doc_get(f"spaces/{r['space_id']}/lists/{r['list_id']}")
    assert r["space_id"] == "p_lister" and lst["item_refs"] == [] and lst["section"] == "workout"
    bad = client.post("/v1/spaces/p_mahmoud/lists", json={"section": "workout", "name": "x"}, headers=me)
    assert bad.status_code == 404
