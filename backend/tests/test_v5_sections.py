"""V5 sections (Watch & Read, Products), affiliate links, search text and notification lines."""

import json

from app import notify, search
from app.pipeline import products
from app.schemas import ExtractResult, FileUnder
from tests.test_pipeline import SAMPLE

SEVERANCE = {
    "type": "entertainment",
    "confidence": 0.9,
    "items": [
        {
            "kind": "series",
            "title": "Severance",
            "creator": "Dan Erickson",
            "year": 2022,
            "genres": ["Thriller"],
            "seasons": 2,
            "platforms": ["Apple TV+"],
            "estimated": True,
            "t": 4.0,
        },
        {"kind": "book", "title": "Project Hail Mary", "creator": "Andy Weir", "t": 20.0},
    ],
}
MUG = {
    "type": "products",
    "confidence": 0.88,
    "items": [
        {
            "name": "Insulated mug",
            "brand": "Stanley",
            "price": 850,
            "currency": "EGP",
            "merchant": "Amazon.eg",
            "url_guess": "https://www.amazon.eg/dp/B01",
            "t": 6.0,
        }
    ],
}


def _result(*sections):
    return ExtractResult.model_validate({**SAMPLE.model_dump(), "sections": list(sections)})


def test_new_sections_validate_and_can_be_filed_under():
    r = _result(SEVERANCE, MUG)
    assert [s.type for s in r.sections] == ["entertainment", "products"]
    assert r.sections[0].items[0].estimated and r.sections[0].items[1].kind == "book"
    assert r.sections[1].items[0].price == 850
    assert FileUnder(section="entertainment").section == "entertainment"
    assert FileUnder(section="products").section == "products"


def test_notification_lines_for_new_sections():
    assert notify.key_line(_result(SEVERANCE))[0] == "To watch: Severance +1 more"
    book = {**SEVERANCE, "items": [SEVERANCE["items"][1]]}
    assert notify.key_line(_result(book))[0] == "To read: Project Hail Mary"
    assert notify.key_line(_result(MUG))[0] == "Product saved: Insulated mug · EGP 850"


def test_search_finds_titles_creators_brands_and_genres():
    r = _result(SEVERANCE, MUG)
    items = [{"section": s.type, "data": s.model_dump()} for s in r.sections]
    text = search.search_text({"caption": None}, r, items)
    for word in ("severance", "erickson", "thriller", "stanley", "insulated mug"):
        assert word in text


def test_affiliate_links_only_where_configured(monkeypatch):
    items = [{"section": "products", "data": MUG}, {"section": "tools", "data": {"items": []}}]
    monkeypatch.delenv("AFFILIATE_RULES", raising=False)
    products.link(items)
    assert "affiliate_url" not in items[0]["data"]["items"][0]

    monkeypatch.setenv("AFFILIATE_RULES", json.dumps({"amazon.eg": {"param": "tag", "value": "rb-21"}}))
    products.link(items)
    p = items[0]["data"]["items"][0]
    assert p["affiliate_url"] == "https://www.amazon.eg/dp/B01?tag=rb-21"
    assert p["url_guess"] == "https://www.amazon.eg/dp/B01"  # the original stays

    table = products.rules()
    assert products.affiliate("https://noon.com/x", table) is None
    assert (
        products.affiliate("https://smile.amazon.eg/x?tag=someone", table)
        == "https://smile.amazon.eg/x?tag=rb-21"
    )
    monkeypatch.setenv("AFFILIATE_RULES", "{not json")
    assert products.rules() == {}
