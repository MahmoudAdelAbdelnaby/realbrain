"""P1-12 without billing: place coordinates from OpenStreetMap's Nominatim (free, no key).

Policy: at most 1 request/s and a real User-Agent; a handful of places per save fits.
ponytail: Nominatim is weaker than Google Places for small Cairo cafés and has no picker; a
miss leaves the place unpinned (Open in Maps still works). Google Places once Blaze is on.
"""

import logging
import time

import httpx

log = logging.getLogger("reelbrain.geo")
NOMINATIM = "https://nominatim.openstreetmap.org/search"
UA = {"User-Agent": "Reelbrain/0.1 (personal, low volume)"}


def _query(http: httpx.Client, q: str) -> dict | None:
    r = http.get(NOMINATIM, params={"q": q, "format": "jsonv2", "limit": 1}, headers=UA)
    r.raise_for_status()
    hits = r.json()
    return hits[0] if hits else None


def locate(places: list[dict], gap_s: float = 1.0) -> list[dict]:
    """Adds `geo` {lat, lng, label, matched} to each place it finds: the full name first, then
    without the area (the AI's area guesses are often off), then the area alone (approximate)."""
    first = True
    with httpx.Client(timeout=10) as http:
        for p in places:
            name, area, city = p.get("name"), p.get("area"), p.get("city")
            tries = [("place", (name, area, city)), ("place", (name, city))]
            if area:
                tries.append(("area", (area, city)))
            seen = set()
            for matched, parts in tries:
                q = ", ".join(s for s in parts if s)
                if not q or q in seen:
                    continue
                seen.add(q)
                if not first:
                    time.sleep(gap_s)
                first = False
                try:
                    hit = _query(http, q)
                except Exception as e:  # noqa: BLE001 - a pin is a bonus; the place still lands
                    log.warning("geocode %r failed: %s", q, e)
                    break
                if hit:
                    p["geo"] = {
                        "lat": float(hit["lat"]),
                        "lng": float(hit["lon"]),
                        "label": hit.get("display_name"),
                        "matched": matched,
                    }
                    break
    return places
