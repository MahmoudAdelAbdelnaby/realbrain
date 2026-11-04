"""V5 Products: optional affiliate links, configured per shop, never replacing the original.

AFFILIATE_RULES is JSON mapping a shop's domain to the query parameter it uses for an affiliate
tag, e.g. {"amazon.eg": {"param": "tag", "value": "realbrain-21"}}. With no rules (the default),
no product gets an affiliate link. The app shows the original link next to any affiliate one and
says when a link is an affiliate link.
"""

import json
import logging
import os
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

log = logging.getLogger("reelbrain.products")


def rules() -> dict[str, dict[str, str]]:
    raw = os.environ.get("AFFILIATE_RULES", "").strip()
    if not raw:
        return {}
    try:
        parsed = json.loads(raw)
    except ValueError:
        log.warning("AFFILIATE_RULES is not valid JSON; affiliate links are off")
        return {}
    return {
        d.lower(): r
        for d, r in parsed.items()
        if isinstance(r, dict) and isinstance(r.get("param"), str) and isinstance(r.get("value"), str)
    }


def affiliate(url: str | None, table: dict[str, dict[str, str]] | None = None) -> str | None:
    """The affiliate version of url when its shop has a rule; None otherwise."""
    if not url:
        return None
    table = rules() if table is None else table
    if not table:
        return None
    u = urlparse(url if "://" in url else "https://" + url)
    host = (u.hostname or "").lower()
    for domain, rule in table.items():
        if host == domain or host.endswith("." + domain):
            query = [(k, v) for k, v in parse_qsl(u.query, keep_blank_values=True) if k != rule["param"]]
            query.append((rule["param"], rule["value"]))
            return urlunparse(u._replace(query=urlencode(query)))
    return None


def link(items: list[dict]) -> None:
    """Adds affiliate_url to products whose shop has a rule (the original url_guess stays)."""
    table = rules()
    if not table:
        return
    for item in items:
        if item["section"] != "products":
            continue
        for product in item["data"].get("items") or []:
            aff = affiliate(product.get("url_guess"), table)
            if aff:
                product["affiliate_url"] = aff
