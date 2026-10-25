from app import notify, recall, store

NOW = 1_800_000_000.0
DAY = 86400


def save(sid, age_days, status="ready"):
    return {"save_id": sid, "space_id": "p_r", "status": status, "created_at": NOW - age_days * DAY, "summary": sid}


def item(sid, **kw):
    return {"save_id": sid, "section": "recipe", "user_state": None, **kw}


def test_due_is_old_untried_unsnoozed_ready_oldest_first():
    saves = [save("old", 90), save("week", 10), save("new", 2), save("busy", 30, "extracting")]
    items = [
        item("old"),
        item("week"),
        item("new"),
        item("busy"),
        item("week", user_state="cooked"),
        item("old", recall_after=NOW + DAY),  # snoozed copy
        item("old", user_state="archived"),
    ]
    assert [s["save_id"] for _, s in recall.due(saves, items, NOW)] == ["old", "week"]


def test_ago_reads_naturally():
    assert recall.ago(3 * DAY) == "3 days"
    assert recall.ago(20 * DAY) == "2 weeks"
    assert recall.ago(95 * DAY) == "3 months"


def test_one_push_a_day_and_none_when_turned_off(monkeypatch):
    sent = []
    monkeypatch.setattr(notify, "push", lambda uid, title, body, data: sent.append((uid, title, body)) or 1)
    store.doc_set("users/recaller", {"spaces": {"me": "p_r"}})
    store.doc_set("users/quiet", {"spaces": {"me": "p_r"}, "settings": {"recall": False}})
    s = save("koshari", 40)
    store.doc_set("spaces/p_r/saves/koshari", s)
    store.col_replace("spaces/p_r/saves/koshari/items", {"0-recipe": item("koshari")})
    recall.run_once(NOW)  # other test users share the local store; look only at ours
    mine = [p for p in sent if p[0] in ("recaller", "quiet")]
    assert mine == [("recaller", "Remember this?", "5 weeks ago you saved: koshari")]
    assert recall.run_once(NOW) == 0, "everyone already had today's"
