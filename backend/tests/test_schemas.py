import json
from pathlib import Path

import pytest
from pydantic import ValidationError

from app.schemas import ExtractResult, Recipe, gemini_schema, needs_review

SAMPLE = (Path(__file__).parent / "sample_extract.json").read_text("utf-8")


def test_contract_sample_validates_into_typed_sections():
    r = ExtractResult.model_validate_json(SAMPLE)
    assert [type(s).__name__ for s in r.sections] == [
        "FactCheck",
        "Tools",
        "Recipe",
        "Places",
        "Workout",
    ]
    recipe = r.sections[2]
    assert isinstance(recipe, Recipe) and recipe.ingredients[0].name == "عدس"
    assert not needs_review(r)


def test_low_confidence_or_empty_goes_to_inbox():
    data = json.loads(SAMPLE)
    for s in data["sections"]:
        s["confidence"] = 0.5
    assert needs_review(ExtractResult.model_validate(data))
    data["sections"] = []
    assert needs_review(ExtractResult.model_validate(data))


def test_rejects_unknown_section_and_bad_confidence():
    data = json.loads(SAMPLE)
    data["sections"] = [{"type": "horoscope", "confidence": 0.9}]
    with pytest.raises(ValidationError):
        ExtractResult.model_validate(data)
    data["sections"] = [{"type": "fact_check", "confidence": 1.5, "claims": []}]
    with pytest.raises(ValidationError):
        ExtractResult.model_validate(data)


def test_gemini_schema_is_plain_json_schema():
    schema = gemini_schema(ExtractResult)
    text = json.dumps(schema)
    assert '"default"' not in text and '"anyOf"' in text and "fact_check" in text
    assert all("title" not in d for d in schema["$defs"].values())
    assert "title" in schema["$defs"]["Recipe"]["properties"], "field names must survive"


def test_memory_card_fields_are_optional_and_checked():
    data = json.loads(SAMPLE)
    assert ExtractResult.model_validate(data).good_for is None  # older replies still validate
    data.update(good_for="Quick weeknight dinner", effort_min=35, difficulty="easy", impact="high")
    r = ExtractResult.model_validate(data)
    assert (r.good_for, r.effort_min, r.difficulty, r.impact) == ("Quick weeknight dinner", 35, "easy", "high")
    with pytest.raises(ValidationError):
        ExtractResult.model_validate({**data, "difficulty": "brutal"})
