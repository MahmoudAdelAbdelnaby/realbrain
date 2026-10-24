from pathlib import Path

from app.schemas import ExtractResult
from app.search import normalise, search_text

SAMPLE = ExtractResult.model_validate_json((Path(__file__).parent / "sample_extract.json").read_text("utf-8"))


def test_arabic_is_folded_and_diacritics_dropped():
    assert normalise("طَماطِم  مُقَشَّرة") == "طماطم مقشره"
    assert normalise("إسكندرية") == normalise("اسكندريه")
    assert normalise("Claude CODE") == "claude code"


def test_search_text_covers_summary_transcript_and_item_names():
    items = [{"section": s.type, "data": s.model_dump()} for s in SAMPLE.sections]
    text = search_text({"caption": "koshari #recipe", "creator": "chef"}, SAMPLE, items)
    for needle in (
        "كشري",
        "how to make koshari",
        "النهارده",
        "github.com/example",
        "uv",
        "عدس",
        "abou tarek",
        "plank",
        "chef",
    ):
        assert normalise(needle) in text, needle
