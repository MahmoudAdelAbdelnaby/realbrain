"""P1-09: tool URLs are guesses until checked. HTTP check for every link; GitHub API for repos
(stars, last push, description), with a name search when the guess is wrong.

ponytail: unauthenticated GitHub API (60 requests/hour per IP); set GITHUB_TOKEN if it bites.
"""

import logging
import os
import re
from urllib.parse import urlparse

import httpx

log = logging.getLogger("reelbrain.tools")
GITHUB = "https://api.github.com"
UA = {"User-Agent": "Reelbrain/0.1 (+personal)"}
REPO = re.compile(r"^/([\w.-]+)/([\w.-]+?)(?:\.git)?/?$")


def _gh_headers() -> dict:
    token = os.environ.get("GITHUB_TOKEN")
    return {
        **UA,
        "Accept": "application/vnd.github+json",
        **({"Authorization": f"Bearer {token}"} if token else {}),
    }


def repo_of(url: str | None) -> tuple[str, str] | None:
    """(owner, repo) for a github.com/<owner>/<repo> URL."""
    if not url:
        return None
    u = urlparse(url if "://" in url else "https://" + url)
    if u.hostname not in ("github.com", "www.github.com"):
        return None
    m = REPO.match(u.path)
    return (m.group(1), m.group(2)) if m else None


def _repo_in(text: str | None) -> tuple[str, str] | None:
    m = re.search(r"github\.com/([\w.-]+)/([\w.-]+)", text or "")
    return (m.group(1), m.group(2).removesuffix(".git")) if m else None


def _repo_info(http: httpx.Client, owner: str, name: str) -> dict | None:
    r = http.get(f"{GITHUB}/repos/{owner}/{name}", headers=_gh_headers())
    if r.status_code != 200:
        return None
    d = r.json()
    return {
        "url": d["html_url"],
        "stars": d.get("stargazers_count"),
        "last_commit": d.get("pushed_at"),
        "description": d.get("description"),
        "archived": d.get("archived", False),
    }


def _search_repo(http: httpx.Client, name: str) -> dict | None:
    """Best GitHub match by name; only when the repo name equals the tool's name (no guessing)."""
    r = http.get(
        f"{GITHUB}/search/repositories", params={"q": f"{name} in:name", "per_page": 5}, headers=_gh_headers()
    )
    if r.status_code != 200:
        return None
    want = re.sub(r"[^a-z0-9]", "", name.lower())
    for item in r.json().get("items", []):
        if re.sub(r"[^a-z0-9]", "", item["name"].lower()) == want:
            owner, repo = item["full_name"].split("/", 1)
            return _repo_info(http, owner, repo)
    return None


def _alive(http: httpx.Client, url: str) -> str | None:
    """Final URL if it answers below 400 (HEAD, then GET for sites that refuse HEAD)."""
    for method in ("HEAD", "GET"):
        try:
            r = http.request(method, url, headers=UA, follow_redirects=True)
        except httpx.HTTPError:
            return None
        if r.status_code < 400:
            return str(r.url)
        if r.status_code not in (403, 405):
            return None
    return None


def verify(items: list[dict]) -> list[dict]:
    """Adds `verified` to each tool: {ok, url, source, stars?, last_commit?, description?}."""
    out = []
    with httpx.Client(timeout=10) as http:
        for tool in items:
            v = {"ok": False, "url": None, "source": None}
            try:
                guess = tool.get("url_guess")
                repo = repo_of(guess)
                info = _repo_info(http, *repo) if repo else None
                matched = "url"
                if info is None:
                    # A repo link shown in the reel (snippet/on screen) beats a name search.
                    shown = _repo_in(tool.get("snippet"))
                    info = _repo_info(http, *shown) if shown else None
                    matched = "snippet"
                if info is None and (repo or tool.get("kind") == "github_repo"):
                    info = _search_repo(http, tool.get("name", ""))
                    matched = "name"  # same name, maybe another project: the app says so
                if info:
                    v = {"ok": True, "source": "github", "matched_by": matched, **info}
                elif guess and not repo:
                    url = guess if "://" in guess else "https://" + guess
                    final = _alive(http, url)
                    v = {"ok": bool(final), "url": final or url, "source": "http"}
            except Exception as e:  # noqa: BLE001 - verification is best effort per tool
                log.info("verify %s failed: %s", tool.get("name"), e)
            out.append({**tool, "verified": v})
    return out
