from pathlib import Path

from scripts.regression import FIXTURE, judge, rows


def test_fixture_rows_parse():
    parsed = rows(FIXTURE.read_text("utf-8"))
    assert parsed and all(r["url"].startswith("http") for r in parsed)
    assert {r["expected"] for r in parsed} <= {"fact_check", "tools", "recipe", "places", "workout", "none"}


def test_rows_skip_header_and_placeholder_lines():
    text = "| # | Platform | URL |\n| --- | --- |\n| 1 | TikTok |  |  |  |  |\n| 2 | TikTok | https://x.y/a | en | recipe | |"
    assert rows(text) == [{"n": "2", "platform": "tiktok", "url": "https://x.y/a", "expected": "recipe"}]


def test_judging():
    assert judge("tools", [("tools", 0.95), ("fact_check", 0.85)])
    assert not judge("fact_check", [("tools", 0.95), ("fact_check", 0.85)]), "the top section must match"
    assert judge("tools", [("fact_check", 0.95), ("tools", 0.95)]), "a tie for top counts"
    assert not judge("recipe", [("recipe", 0.4)]), "too unsure: it would go to review"
    assert judge("none", [("fact_check", 0.5)])
    assert not judge("none", [("fact_check", 0.9)])


def test_fixture_path_points_at_the_repo_test_set():
    assert FIXTURE == Path(__file__).resolve().parent.parent.parent / "test" / "fixtures" / "reels.md"
