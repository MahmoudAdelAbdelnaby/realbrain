"""The AI contract (docs/BUILD_PLAN.md "AI contract") as Pydantic models. Locked: change the doc first."""

from typing import Literal

from pydantic import BaseModel, Field, model_validator


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
    tags: list[str] = Field(
        default_factory=list,
        description="2-4 short tags: cuisine, meal, diet, e.g. Egyptian, dinner, vegetarian",
    )


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


class Ideas(BaseModel):
    """Design v4 §5.4: a thought worth keeping (typed in Create, or a video that is mostly a tip)."""

    type: Literal["ideas"]
    confidence: float = Field(ge=0, le=1)
    title: str
    idea: str = Field(description="The idea in a sentence or two")
    next_steps: list[str] = Field(default_factory=list, description="1-3 concrete things to do with it")


class Title(BaseModel):
    """V5 Watch & Read: one film, series or book the video recommends."""

    kind: Literal["movie", "series", "book"]
    title: str
    creator: str | None = Field(None, description="Director or showrunner (films, series) or author (books)")
    year: int | None = None
    genres: list[str] = Field(default_factory=list, description="1-3 genres")
    premise: str | None = Field(None, description="What it is about, in a sentence")
    why: str | None = Field(None, description="Why the video recommends it, in its words")
    seasons: int | None = None
    episodes: int | None = None
    platforms: list[str] = Field(
        default_factory=list, description="Where to watch or read, only if the video says"
    )
    estimated: bool = Field(
        False, description="True when any detail comes from general knowledge, not the video"
    )
    t: float


class Entertainment(BaseModel):
    type: Literal["entertainment"]
    confidence: float = Field(ge=0, le=1)
    items: list[Title]


class Product(BaseModel):
    """V5 Products: something the video shows or recommends buying."""

    name: str
    brand: str | None = None
    description: str | None = None
    specs: list[str] = Field(default_factory=list, description="Up to 5 short specs said or shown")
    price: float | None = Field(None, description="Only a price the video states")
    currency: str | None = Field(None, description="ISO code, e.g. EGP, USD")
    price_text: str | None = Field(
        None, description="The price as said when it is not one number, e.g. under 500 pounds"
    )
    merchant: str | None = Field(None, description="Where to buy it, if said")
    url_guess: str | None = None
    why: str | None = Field(None, description="Why the video recommends it")
    t: float


class Products(BaseModel):
    type: Literal["products"]
    confidence: float = Field(ge=0, le=1)
    items: list[Product]


# Plain union (anyOf), not a discriminated one: Gemini's schema support is safest with anyOf,
# and the Literal `type` still makes validation pick the right model.
Section = FactCheck | Tools | Recipe | Places | Workout | Ideas | Entertainment | Products

SECTIONS = Literal["fact_check", "tools", "recipe", "places", "workout", "ideas", "entertainment", "products"]


class ExtractResult(BaseModel):
    language: str = Field(description="BCP-47 tag of the video's main language, e.g. ar-EG, en-US")
    summary: str = Field(description="One or two sentences in the video's language")
    summary_en: str
    transcript: list[Timed]
    on_screen_text: list[Timed]
    sections: list[Section]
    key_frame_t: float | None = None
    # Design v4 §5.1: the save as a whole, for the memory card ("Why you saved this", chips).
    good_for: str | None = Field(
        None,
        max_length=80,
        description="Who or when it is good for, at most 60 chars, in the video's language, e.g. Quick weeknight dinner",
    )
    effort_min: int | None = Field(None, ge=0, description="Minutes it takes to try, cook, do or use it")
    difficulty: Literal["easy", "medium", "hard"] | None = None
    impact: Literal["low", "medium", "high"] | None = Field(
        None, description="How much it could change the viewer's day or work"
    )
    # Design v4 step 5 (Threads): what connects this save to others, across sections.
    topics: list[str] = Field(
        default_factory=list,
        description="2-4 short topics in English, lowercase, whatever the video's language, e.g. meal prep, ai agents, cairo cafes",
    )


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
    # A link, or (design v4 step 3) a typed idea with no link.
    source_url: str | None = Field(None, pattern=r"^https?://")
    idea: str | None = Field(None, min_length=1, max_length=2000)
    space_id: str = Field(min_length=1, max_length=128)
    note: str | None = Field(None, max_length=2000)
    # Optional, from the phone's yt-dlp metadata; fill the save doc's caption/creator fields.
    caption: str | None = Field(None, max_length=5000)
    creator: str | None = Field(None, max_length=200)
    # The phone's own id for this share. Retries send the same one and get the same save back,
    # so a failed upload can't leave an orphan behind.
    client_id: str | None = Field(None, pattern=r"^[A-Za-z0-9-]{8,64}$")
    # Create's "What is this?": Extract runs with it as a hint, as a correction would.
    section_hint: SECTIONS | None = None

    @model_validator(mode="after")
    def _link_or_idea(self):
        if (self.source_url is None) == (self.idea is None):
            raise ValueError("send source_url or idea, not both or neither")
        return self


class CreatedSave(BaseModel):
    save_id: str
    upload_url: str
    # "received" means upload now; anything else means this share already went through.
    status: str = "received"


class FileUnder(BaseModel):
    # "none": nothing fits; keep it as a plain save.
    section: Literal[
        "fact_check", "tools", "recipe", "places", "workout", "ideas", "entertainment", "products", "none"
    ]


class NoVideo(BaseModel):
    reason: str = Field(max_length=200)


class ProcessTask(BaseModel):
    save_id: str


class Me(BaseModel):
    name: str | None = Field(None, max_length=200)
    lang: str | None = Field(None, max_length=10)
    fcm_token: str | None = Field(None, max_length=4096)  # P1-06: this phone's push token


class CreateHousehold(BaseModel):
    name: str = Field("Home", min_length=1, max_length=60)


class CreateGroup(BaseModel):
    """V5 groups: any number per person; the first one becomes the "Home" share target."""

    name: str = Field(min_length=1, max_length=60)


class ShareSave(BaseModel):
    """V5: share a save into a group (the group gets its own copy) with a post on its wall."""

    space_id: str = Field(min_length=1, max_length=128)
    item_id: str | None = Field(None, max_length=64)
    kind: Literal["share", "plan", "cook", "challenge"] = "share"
    when: float | None = Field(
        None, ge=0, description="Epoch seconds: the plan, the cook-along, the challenge deadline"
    )
    text: str | None = Field(None, max_length=280)

    @model_validator(mode="after")
    def _when_for_activities(self):
        if self.kind != "share" and self.when is None:
            raise ValueError("plans, cook-alongs and challenges need a time")
        return self


class CommentBody(BaseModel):
    """A comment on a wall post; `result` (a cook-along photo) and `proof` (a challenge) carry a photo."""

    kind: Literal["comment", "result", "proof"] = "comment"
    text: str | None = Field(None, max_length=1000)
    photo_b64: str | None = Field(None, max_length=6_000_000)

    @model_validator(mode="after")
    def _something(self):
        if not (self.text or "").strip() and not self.photo_b64:
            raise ValueError("send text or a photo")
        return self


class CreateList(BaseModel):
    section: SECTIONS
    name: str = Field(min_length=1, max_length=60)


class Settings(BaseModel):
    lang: Literal["system", "en", "ar"] | None = None
    theme: Literal["system", "light", "dark"] | None = None
    # Design v4 Recall: one "Remember this?" push a day; on unless turned off.
    recall: bool | None = None
    # V5 My Brain: show the puzzle (progress counts either way).
    puzzle: bool | None = None
