import httpx

from app.pipeline import geo


def fake(request: httpx.Request) -> httpx.Response:
    q = request.url.params["q"]
    hits = {
        "Aroya, Cairo": [{"lat": "30.05", "lon": "31.22", "display_name": "Aroya, Zamalek, Cairo"}],
        "Zamalek, Cairo": [{"lat": "30.06", "lon": "31.22", "display_name": "Zamalek"}],
    }
    return httpx.Response(200, json=hits.get(q, []))


def run(places, monkeypatch):
    real = httpx.Client
    monkeypatch.setattr(geo.httpx, "Client", lambda **kw: real(transport=httpx.MockTransport(fake), **kw))
    return geo.locate(places, gap_s=0)


def test_wrong_area_falls_back_to_name_and_city(monkeypatch):
    [p] = run([{"name": "Aroya", "area": "Maadi", "city": "Cairo"}], monkeypatch)
    assert p["geo"] == {"lat": 30.05, "lng": 31.22, "label": "Aroya, Zamalek, Cairo", "matched": "place"}


def test_unknown_place_pins_the_area_as_approximate(monkeypatch):
    [p] = run([{"name": "Tiny cafe", "area": "Zamalek", "city": "Cairo"}], monkeypatch)
    assert p["geo"]["matched"] == "area"


def test_nothing_found_leaves_the_place_unpinned(monkeypatch):
    [p] = run([{"name": "Nowhere"}], monkeypatch)
    assert "geo" not in p
