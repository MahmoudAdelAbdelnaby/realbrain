"""The AI contract (docs/BUILD_PLAN.md "AI contract") as Pydantic models. Locked: change the doc first."""

from typing import Literal

from pydantic import BaseModel, Field


class Timed(BaseModel):
    t: float
    text: str


class FactCheck(BaseModel):
    type: Literal["fact_check"]
    confidence: float = Field(ge=0, le=1)
    claims: list[Timed]


class Tool(BaseModel):
    name: str
    url_guess: str | None = None
    kind: str | None = Field(None, description="github_repo, website, app, cli, library, extension, other")
    use_shown: str | None = None
    snippet: str | None = None
    t: float


class Tools(BaseModel):
    type: Literal["tools"]
    confidence: float = Field(ge=0, le=1)
    items: list[Tool]


class Ingredient(BaseModel):
    name: str
    qty: float | None = None
    unit: str | None = None
    estimated: bool = False


class Step(BaseModel):
    text: str
    timer_s: int | None = None
    t: float


class Recipe(BaseModel):
    type: Literal["recipe"]
    confidence: float = Field(ge=0, le=1)
    title: str
    servings: int | None = None
    total_min: int | None = None
    ingredients: list[Ingredient]
    steps: list[Step]


class Place(BaseModel):
    name: str
    area: str | None = None
    city: str | None = None
    why_go: str | None = None
    what_to_order: str | None = None
    t: float


class Places(BaseModel):
    type: Literal["places"]
    confidence: float = Field(ge=0, le=1)
    items: list[Place]


class Exercise(BaseModel):
    name: str
    duration_s: int | None = None
    reps: int | None = None
    sets: int | None = None
    rest_s: int | None = None
    cues: str | None = None
    t: float
    estimated: bool = False


class Workout(BaseModel):
    type: Literal["workout"]
    confidence: float = Field(ge=0, le=1)
    exercises: list[Exercise]


# Plain union (anyOf), not a discriminated one: Gemini's schema support is safest with anyOf,
# and the Literal `type` still makes validation pick the right model.
Section = FactCheck | Tools | Recipe | Places | Workout


class ExtractResult(BaseModel):
    language: str = Field(description="BCP-47 tag of the video's main language, e.g. ar-EG, en-US")
    summary: str = Field(description="One or two sentences in the video's language")
    summary_en: str
    transcript: list[Timed]
    on_screen_text: list[Timed]
    sections: list[Section]
    key_frame_t: float | None = None


REVIEW_BELOW = 0.6


def needs_review(result: ExtractResult) -> bool:
    """No section, or the best one is below the confidence bar: send to Inbox."""
    return not result.sections or max(s.confidence for s in result.sections) < REVIEW_BELOW


def gemini_schema(model: type[BaseModel]) -> dict:
    """JSON Schema for Gemini structured output, minus keywords it doesn't need (default, title)."""

    def strip(node, in_properties=False):
        # Keys under "properties" are field names (Recipe has a field called title): keep those.
        if isinstance(node, dict):
            return {
                k: strip(v, k == "properties")
                for k, v in node.items()
                if in_properties or k not in ("default", "title")
            }
        if isinstance(node, list):
            return [strip(v) for v in node]
        return node

    return strip(model.model_json_schema())


# --- API bodies (docs/BUILD_PLAN.md "Backend contract") ---


class CreateSave(BaseModel):
    source_url: str = Field(pattern=r"^https?://")
    space_id: str = Field(min_length=1, max_length=128)
    note: str | None = Field(None, max_length=2000)
    # Optional, from the phone's yt-dlp metadata; fill the save doc's caption/creator fields.
    caption: str | None = Field(None, max_length=5000)
    creator: str | None = Field(None, max_length=200)


class CreatedSave(BaseModel):
    save_id: str
    upload_url: str


class NoVideo(BaseModel):
    reason: str = Field(max_length=200)


class ProcessTask(BaseModel):
    save_id: str
