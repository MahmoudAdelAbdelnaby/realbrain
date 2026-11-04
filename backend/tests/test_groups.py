"""V5 groups: several groups, invites, the share target, leaving, sharing into a group, the wall."""

import base64
import time

from fastapi.testclient import TestClient

from app import store
from app.main import app

client = TestClient(app)
ANA = {"Authorization": "Bearer dev:ana"}
BEN = {"Authorization": "Bearer dev:ben"}
CY = {"Authorization": "Bearer dev:cy"}
STRANGER = {"Authorization": "Bearer dev:stranger2"}

# A 1x1 JPEG.
JPEG = base64.b64decode(
    "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////"
    "////////////////////////////wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/"
    "2gAIAQEAAD8AKp//2Q=="
)


def _me(headers, name):
    client.post("/v1/me", json={"name": name}, headers=headers)


def _ready_save(space_id: str, by: str) -> str:
    """A finished recipe save, as the pipeline writes it."""
    save_id = f"s{time.time_ns()}"
    store.create_save(
        save_id,
        {
            "space_id": space_id,
            "status": "ready",
            "summary": "Molokhia with garlic tasha",
            "key_frame_url": "/dev/frames/x/f.jpg",
            "created_by": by,
            "sections": ["recipe"],
        },
    )
    save = store.get_save(save_id)
    store.put_items(
        save,
        [
            {
                "section": "recipe",
                "confidence": 0.9,
                "data": {"title": "Molokhia", "servings": 4, "total_min": 35},
                "user_state": "cooked",
                "seen": {by: 1.0},
                "done_at": 2.0,
            }
        ],
    )
    return save_id


def test_groups_invites_share_target_and_leaving():
    _me(ANA, "Ana Lima")
    _me(BEN, "Ben")
    first = client.post("/v1/groups", json={"name": "Home"}, headers=ANA).json()
    assert first["code"] == first["invite_url"].rsplit("/", 1)[1] and len(first["code"]) == 8
    home = first["space_id"]
    space = store.doc_get(f"spaces/{home}")
    assert (
        space["type"] == "group" and space["members"] == ["ana"] and space["member_names"] == {"ana": "Ana"}
    )
    ana = store.doc_get("users/ana")
    assert ana["spaces"]["home"] == home and ana["groups"] == [home]

    # A second group doesn't take over the share target.
    trip = client.post("/v1/groups", json={"name": "Alex trip"}, headers=ANA).json()["space_id"]
    assert store.doc_get("users/ana")["spaces"]["home"] == home
    assert store.doc_get("users/ana")["groups"] == [home, trip]

    # Ben joins the trip: it becomes his Home (his first group), and his name shows in the group.
    code = client.post(f"/v1/spaces/{trip}/invite", headers=ANA).json()["code"]
    assert client.post(f"/v1/invites/{code}/accept", headers=BEN).json() == {"space_id": trip}
    assert store.doc_get(f"spaces/{trip}")["member_names"] == {"ana": "Ana", "ben": "Ben"}
    assert store.doc_get("users/ben")["spaces"]["home"] == trip

    # Ana makes the trip her share target, then leaves it: Home takes over again.
    assert client.post(f"/v1/groups/{trip}/default", headers=ANA).status_code == 200
    assert store.doc_get("users/ana")["spaces"]["home"] == trip
    assert client.post(f"/v1/groups/{trip}/leave", headers=ANA).status_code == 200
    ana = store.doc_get("users/ana")
    assert ana["spaces"]["home"] == home and ana["groups"] == [home]
    assert store.doc_get(f"spaces/{trip}")["members"] == ["ben"]
    assert "ana" not in store.doc_get(f"spaces/{trip}")["member_names"]

    # Strangers can't see, invite to, or leave a group; the personal space isn't a group.
    assert client.post(f"/v1/spaces/{home}/invite", headers=STRANGER).status_code == 404
    assert client.post(f"/v1/groups/{home}/default", headers=STRANGER).status_code == 404
    assert client.post("/v1/groups/p_ana/leave", headers=ANA).status_code == 400


def test_sharing_copies_into_the_group_and_posts_on_the_wall():
    _me(CY, "Cy")
    _me(BEN, "Ben")
    g = client.post("/v1/groups", json={"name": "Cooks"}, headers=CY).json()
    code = g["code"]
    gid = g["space_id"]
    client.post(f"/v1/invites/{code}/accept", headers=BEN)
    original = _ready_save("p_cy", "cy")

    when = time.time() + 86400
    r = client.post(
        f"/v1/saves/{original}/share",
        json={"space_id": gid, "item_id": "0-recipe", "kind": "cook", "when": when, "text": "Thursday?"},
        headers=CY,
    )
    assert r.status_code == 200, r.text
    copy_id, post_id = r.json()["save_id"], r.json()["post_id"]
    copy = store.get_save(copy_id)
    assert copy["space_id"] == gid and copy["shared_by"] == "cy"
    assert copy["shared_from"] == {"space_id": "p_cy", "save_id": original}
    (item,) = store.get_items(copy)
    # Personal progress stays personal: the group's copy starts fresh.
    assert item["user_state"] is None and "seen" not in item and "done_at" not in item
    assert item["space_id"] == gid and item["data"]["title"] == "Molokhia"

    post = store.doc_get(f"spaces/{gid}/posts/{post_id}")
    assert post["kind"] == "cook" and post["title"] == "Molokhia" and post["detail"] == "35 min · serves 4"
    assert post["by_name"] == "Cy" and post["rsvp"] == {"cy": "going"} and post["when"] == when
    assert post["noun"] == "recipe" and post["text"] == "Thursday?" and post["comment_count"] == 0

    # Sharing again reuses the copy; Ben (a member) sees it, a stranger can't share into the group.
    again = client.post(f"/v1/saves/{original}/share", json={"space_id": gid}, headers=CY).json()
    assert again["save_id"] == copy_id
    assert (
        client.post(f"/v1/saves/{original}/share", json={"space_id": gid}, headers=STRANGER).status_code
        == 404
    )
    # Plans, cook-alongs and challenges need a time.
    assert (
        client.post(
            f"/v1/saves/{original}/share", json={"space_id": gid, "kind": "plan"}, headers=CY
        ).status_code
        == 422
    )

    # Comments: text, a photo as proof or result; the post counts them; proof marks you done.
    path = f"/v1/spaces/{gid}/posts/{post_id}/comments"
    assert client.post(path, json={"text": "I'll bring the garlic"}, headers=BEN).status_code == 200
    photo = base64.b64encode(JPEG).decode()
    assert client.post(path, json={"kind": "result", "photo_b64": photo}, headers=BEN).status_code == 200
    post = store.doc_get(f"spaces/{gid}/posts/{post_id}")
    assert post["comment_count"] == 2 and post["rsvp"]["ben"] == "done"
    comments = store.col_list(f"spaces/{gid}/posts/{post_id}/comments")
    stored = next(c for c in comments if c["photo"])
    assert stored["photo"].startswith(f"/dev/frames/{gid}/post-{post_id}-") and stored["photo"].endswith(
        ".jpg"
    )
    assert stored["by_name"] == "Ben"

    # The bytes decide: not an image, not valid base64, empty, or from a stranger.
    fake = base64.b64encode(b"GIF89a....").decode()
    assert client.post(path, json={"photo_b64": fake}, headers=BEN).status_code == 415
    assert client.post(path, json={"photo_b64": "***"}, headers=BEN).status_code == 422
    assert client.post(path, json={"text": "  "}, headers=BEN).status_code == 422
    assert client.post(path, json={"text": "hi"}, headers=STRANGER).status_code == 404
    assert (
        client.post(f"/v1/spaces/{gid}/posts/nope/comments", json={"text": "x"}, headers=BEN).status_code
        == 404
    )


def test_only_finished_saves_can_be_shared():
    _me(ANA, "Ana")
    gid = client.post("/v1/groups", json={"name": "Later"}, headers=ANA).json()["space_id"]
    save_id = client.post(
        "/v1/saves", json={"source_url": "https://youtu.be/q", "space_id": "me"}, headers=ANA
    ).json()["save_id"]
    assert client.post(f"/v1/saves/{save_id}/share", json={"space_id": gid}, headers=ANA).status_code == 409
