import httpx

from app.pipeline import tools

REPO = {
    "html_url": "https://github.com/astral-sh/uv",
    "stargazers_count": 70000,
    "pushed_at": "2026-10-20T10:00:00Z",
    "description": "An extremely fast Python package manager.",
}


def fake_web(request: httpx.Request) -> httpx.Response:
    url = str(request.url)
    if url == "https://api.github.com/repos/astral-sh/uv":
        return httpx.Response(200, json=REPO)
    if url.startswith("https://api.github.com/repos/"):
        return httpx.Response(404)
    if url.startswith("https://api.github.com/search/repositories"):
        return httpx.Response(200, json={"items": [{"name": "uv", "full_name": "astral-sh/uv"}]})
    if url == "https://ok.example/":
        return httpx.Response(200)
    if url == "https://blocks-head.example/":
        return httpx.Response(405 if request.method == "HEAD" else 200)
    return httpx.Response(404)


def run(items, monkeypatch):
    real = httpx.Client
    monkeypatch.setattr(
        tools.httpx, "Client", lambda **kw: real(transport=httpx.MockTransport(fake_web), **kw)
    )
    return [t["verified"] for t in tools.verify(items)]


def test_repo_urls_are_parsed():
    assert tools.repo_of("https://github.com/astral-sh/uv") == ("astral-sh", "uv")
    assert tools.repo_of("github.com/astral-sh/uv.git") == ("astral-sh", "uv")
    assert tools.repo_of("https://github.com/astral-sh") is None
    assert tools.repo_of("https://gitlab.com/a/b") is None


def test_github_repo_gets_stars_and_last_push(monkeypatch):
    [v] = run(
        [{"name": "uv", "url_guess": "https://github.com/astral-sh/uv", "kind": "github_repo"}], monkeypatch
    )
    assert v["ok"] and v["source"] == "github" and v["stars"] == 70000
    assert v["last_commit"].startswith("2026-10-20")


def test_wrong_repo_guess_falls_back_to_an_exact_name_search(monkeypatch):
    [v] = run(
        [{"name": "uv", "url_guess": "https://github.com/someone/uv", "kind": "github_repo"}], monkeypatch
    )
    assert v["ok"] and v["url"] == "https://github.com/astral-sh/uv" and v["matched_by"] == "name"


def test_a_repo_link_in_the_snippet_beats_a_name_search(monkeypatch):
    tool = {
        "name": "uv",
        "url_guess": "https://github.com/x/y",
        "snippet": "git clone https://github.com/astral-sh/uv.git",
    }
    [v] = run([tool], monkeypatch)
    assert v["matched_by"] == "snippet" and v["stars"] == 70000


def test_websites_are_checked_and_dead_links_flagged(monkeypatch):
    ok, head, dead, none = run(
        [
            {"name": "A", "url_guess": "https://ok.example/"},
            {"name": "B", "url_guess": "https://blocks-head.example/"},
            {"name": "C", "url_guess": "https://dead.example/"},
            {"name": "D"},
        ],
        monkeypatch,
    )
    assert ok["ok"] and head["ok"] and not dead["ok"] and not none["ok"]
    assert dead["url"] == "https://dead.example/"
