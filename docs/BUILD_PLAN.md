# Build plan

This tab turns the PRD into work: specs that don't change mid-build, then tickets in build order. Tick a ticket only when every acceptance check passes.

## How to work this plan

Build in ticket order, one ticket per Claude Code session, and never start a phase before its gate passes.

- **Ticket format:** `ID · Title`, then acceptance checks. IDs are stable (P0-01, P1-07…) so commits and branches can reference them: `feat(P1-07): recipe card`.
- **Definition of done** for every ticket:
  1. All acceptance checks pass on a real Android phone (not only the emulator).
  2. No lint errors; unit tests for any parsing, schema or timer logic.
  3. Loading, empty and error states designed, not just the happy path.
  4. Works in light and dark mode, and in Arabic (RTL).
  5. Committed with the ticket ID; this checkbox ticked.
- **Specs are locked.** If a ticket needs a spec change (schema, colours, endpoints), update the spec section here first, then code.
- **Real reels for testing:** keep a test set of 20 links (5 per platform, mixed sections, at least 4 in Arabic) in `test/fixtures/reels.md` and re-run it after any AI or download change.

## Setup checklist (you, before P0-01)

About an hour of account setup; nothing here costs money yet except the optional Apple fee.

- [ ] Install Flutter (stable channel), Android Studio and an Android phone with USB debugging on.
- [ ] Create a GitHub repo `reelbrain` (private) and give Claude Code access.
- [ ] Create one Google Cloud / Firebase project `reelbrain-dev`. Enable Firestore, Authentication (Google sign-in), Storage, Cloud Messaging.
- [ ] Attach a billing account with a **$1 budget alert** (Cloud Run requires billing even on the free tier; the alert protects you).
- [ ] Create a Gemini API key in Google AI Studio under the same project; check the free-tier quotas shown there for gemini-2.5-flash and the newest Flash.
- [ ] Enable Places API (New) and Maps SDK for Android; restrict the Maps key to the app's package name.
- [ ] Install the Firebase CLI and `gcloud` CLI; log in to both.
- [ ] Collect the 20-reel test set (see above).
- [ ] Later, before Phase 2: Apple Developer Program ($99/year) and access to a Mac or a cloud build service.

## Locked tech spec

One monorepo: a Flutter app, a Python backend on Cloud Run, and Firebase for data, auth and push.

| Layer | Choice | Why |
| --- | --- | --- |
| App | Flutter (stable), Dart | One codebase for Android and iPhone |
| State / routing | Riverpod, go\_router | Testable, standard in 2026 Flutter apps |
| Share intake | Two native Kotlin share activities (Me, Home) that queue the URL and finish without starting Flutter | Space chosen by the tap; closes in under 1 s |
| On-device download (Android) | youtubedl-android (yt-dlp for Android) behind a Kotlin platform channel | Residential IP, not blocked |
| Data / auth / push | Firestore, Firebase Auth (Google sign-in), Storage, FCM | Offline sync, built-in push |
| Maps | google\_maps\_flutter + Places API (New), called from backend | Key stays server-side |
| Motion and polish | flutter\_animate, Lottie for 2-3 hero animations, wakelock\_plus for cooking/workout modes | Premium feel |
| Backend | Python 3.12, FastAPI, google-genai SDK, ffmpeg, yt-dlp (fallback) | You already know FastAPI; ffmpeg cuts key frames |
| Jobs | Cloud Run service + Cloud Tasks queue, retries with backoff | Survives Gemini 429s |
| CI | GitHub Actions: lint, tests, deploy backend on push to main | Hands-off |

**Repo structure**

```
reelbrain/
  app/                      Flutter app
    lib/core/               theme, router, api client, design tokens
    lib/features/           save, home, inbox, factcheck, tools,
                            recipes, places, workouts, library, settings
    android/.../downloader/ Kotlin platform channel around youtubedl-android
  backend/
    app/main.py             FastAPI entry
    app/pipeline/           fetch.py, extract.py, classify.py, enrich/*.py
    app/schemas/            Pydantic models = the AI contract below
    app/prompts/            one prompt file per section
    tests/
  infra/                    firestore.rules, indexes, Cloud Run + Tasks config
  test/fixtures/reels.md    the 20-reel test set
```

Environments: `dev` only until Phase 2 gate, then add `prod` as a second Firebase project.

## Design system (v2, after Impeccable and Taste review)

Direction: a quiet product UI on Material 3 structure, where the reel's own content is the colour and the chrome stays neutral. Revised on 23 Oct against the Impeccable and Taste skills; what changed from v1 is listed at the end.

**Theme from the use scene, not the category.** Dark by default, because most saves happen in the evening inside TikTok. Cooking mode is always light and high-contrast (bright kitchen, phone on the counter). Everything else follows the system setting.

**Colour: one accent, on data only**

| Token | Dark | Light | Use |
| --- | --- | --- | --- |
| ground | #0E0E0F | #F7F7F5 | App background (true neutral, no navy) |
| surface | #18181A | #FFFFFF | Cards, sheets |
| raised | #222225 | #F0F0EE | Inputs, pressed rows, nested panels |
| line | #2A2A2D | #E6E6E3 | 1 px card edge; never both line and shadow |
| text | #FFFFFF | #111111 | Primary text |
| muted | #B4B4B4 | #5F6368 | Secondary text (≥ 4.5:1) |
| faint | #949494 | #6B6B6B | Meta, timestamps (≥ 4.5:1) |
| primary | #FFFFFF fill, black label | #111111 fill, white label | The one main action per screen |
| accent (signal blue) | #6CB8FF | #1F6FD1 | Moment-strip ticks, timer progress, selected state. Nothing else. |
| true / mixed / false | #3FC07A on #172A1D · #E9B44C on #2D2516 · #E5566F on #2C1A20 | #247B50 on #DCFAE5 · #92400E on #FFFBEB · #831C1E on #FFEDEA | Verdict pills only |

Sections have no colours of their own. A section is named in words with one grey outline icon.

**Type:** IBM Plex Sans with IBM Plex Sans Arabic, one family, tabular figures on every number. Scale 12 / 14 / 16 / 20 / 28; weights 400 / 500 / 600. Two justified exceptions, both read from a distance: the cooking-mode step at 28 and the workout timer digits at 96.

**Shape, space, depth:** 4 pt grid, 16 px side margins, 48 dp minimum touch targets. Soft radius chosen once: cards 20, nested panels 12, controls fully round. Separation by a lightness step and a 1 px line; shadows only on what floats (bottom sheets, menus, the save toast).

**Structure:** Material 3 on Android: opaque navigation bar with four destinations (Feed, Shelves, Map, Ask), top app bar, system Back always works, edge-to-edge insets. On iPhone the same screens honour safe areas, Reduce Motion and edge-swipe back.

**Motion:** 150–250 ms, state only: the save toast, a result card arriving, the timer ticking, a step advancing. No load choreography. Loading is the final layout with flat grey bars at each value's real size, never a shimmer.

**Signature element: the moment strip.** Every result card carries a thin bar the length of the reel, with a tick at each second something was extracted (a claim, an ingredient, an exercise, a tool). Ticks take the verdict colour on Fact Check and the accent elsewhere; tapping one jumps to that item. It exists because every extracted item stores its `t`, so it is data, not decoration, and no competitor has it.

**Removed from v1, and why:** five section colours (colour belongs on data), the frosted glass navigation bar and the shimmer loader (decoration that Taste bans), the violet tools colour (banned palette), the verdict ring (a ring standing in for content; the verdict is now words plus pills), and the serif display face (one family for a product UI).

**Icons:** Phosphor, regular weight, 20 px, grey. **Components to build first:** ResultCard, MomentStrip, VerdictPill, SaveToast, TimerDigits, StepView, EmptyState, BottomSheet, SkeletonCard.

## AI contract

Two Gemini calls per save at most: one **Extract** call that watches the video and returns everything below, then one **Enrich** call only when a section needs the web (Fact Check grounding). Both use structured output against Pydantic models in `backend/app/schemas/`.

**Call 1 — Extract** (newest free Flash model, video file + caption + metadata in, JSON out):

```json
{
  "language": "ar-EG",
  "summary": "One or two sentences in the video's language",
  "summary_en": "Same in English",
  "transcript": [{"t": 3.2, "text": "..."}],
  "on_screen_text": [{"t": 5.0, "text": "github.com/..."}],
  "sections": [
    {"type": "fact_check", "confidence": 0.91,
     "claims": [{"text": "...", "t": 12.0}]},
    {"type": "tools", "confidence": 0.88,
     "items": [{"name": "...", "url_guess": "...", "kind": "github_repo",
                "use_shown": "...", "snippet": "pip install ...", "t": 20.5}]},
    {"type": "recipe", "confidence": 0.95,
     "title": "...", "servings": 4, "total_min": 35,
     "ingredients": [{"name": "...", "qty": 200, "unit": "g", "estimated": false}],
     "steps": [{"text": "...", "timer_s": 600, "t": 41.0}]},
    {"type": "places", "confidence": 0.8,
     "items": [{"name": "...", "area": "Zamalek", "city": "Cairo",
                "why_go": "...", "what_to_order": "...", "t": 8.0}]},
    {"type": "workout", "confidence": 0.9,
     "exercises": [{"name": "Plank", "duration_s": 120, "reps": null, "sets": 1,
                    "rest_s": 30, "cues": "...", "t": 15.0, "estimated": false}]}
  ],
  "key_frame_t": 4.5
}
```

**Call 2 — Fact Check grounding** (gemini-2.5-flash-lite + Google Search tool; changed 24 Oct in P1-08: the API refuses gemini-2.5-flash for new keys and Gemini 3+ grounding is 0/day on the free tier, while 2.5 Flash-Lite grounding works, about 2 s a call). The reply is JSON in text (search can't be combined with JSON mode); sources come from the search citations, or the search queries themselves when there are none: input = the claims list; output = per-claim verdict, one-line correction, 2-3 source URLs, plus an overall label and a notification line of at most 60 characters.

**Prompt rules** (in every prompt file):

- Only extract what is said, shown or written in the video or caption. Anything inferred is marked `estimated: true`.
- Every item carries `t`, the second it appears, used for key frames and "jump to moment".
- Return an empty `sections` array rather than forcing a section; confidence < 0.6 goes to Inbox.
- Arabic videos: keep names and ingredients in Arabic and add an English field where the schema has one.
- Tool URLs are guesses until the backend verifies them with an HTTP check (and the GitHub API for repos).

## Backend contract

The app talks to a small authenticated API; the backend alone writes AI results to Firestore, and the app listens to Firestore for live status.

**Save lifecycle**

`received → fetching → uploaded → extracting → enriching → ready`, with exits to `partial` (caption-only), `needs_review` (confidence < 0.6) and `failed` (after 3 retries). Every state change is written to the save document so the processing card updates live.

**Endpoints** (all require a Firebase ID token in `Authorization: Bearer`):

| Method and path | Body | Returns | Notes |
| --- | --- | --- | --- |
| POST /v1/saves | source\_url, space\_id, note? | save\_id, upload\_url | upload\_url is a signed Storage URL, valid 15 min |
| POST /v1/saves/{id}/uploaded | — | 202 | Enqueues processing |
| POST /v1/saves/{id}/no-video | reason | 202 | Phone couldn't fetch; backend tries the fallback chain |
| POST /v1/saves/{id}/retry | — | 202 | From Inbox |
| POST /v1/saves/{id}/section | section | 200 | User correction; logged for prompt tuning (`corrections/{id}`, backend-only). P1-07: Extract re-runs with the section as a hint, on the kept video (`needs_review` saves keep theirs until resolved) or through the fallback chain |
| POST /v1/saves/{id}/deep-dive | — | 202 | Fact Check explainer on demand (P1-08: per save, one Fact Check item each); written into the item's `explainer` |
| POST /internal/process | save\_id | 200 | Called by Cloud Tasks only (OIDC-verified) |
| POST /v1/me | name?, lang?, fcm\_token? | uid, spaces{me, home?} | Added in P1-03: creates `users/{uid}` and the personal space on first call; idempotent. P1-06: `fcm_token` adds this phone's push target (a Firebase installation ID, FCM's current send target) to `fcm_tokens` |
| POST /v1/spaces/household | name | space\_id, invite\_url | Added in P1-03: one household per user; the creator is the first member |
| POST /v1/spaces/{id}/invite | — | invite\_url | Added in P1-03: new link for a household you're a member of, valid 7 days |
| POST /v1/invites/{code}/accept | — | space\_id | Added in P1-03: adds the caller's uid to `members` |

**Firestore collections**

```
users/{uid}                         name, lang, fcm_tokens[], default_space,
                                    spaces{me, home} (P1-03: maps the share targets to space ids)
invites/{code}                      space_id, created_by, expires_at (backend only)
config/backend                      url, started_at (P1-06: the backend's current address; signed-in users read it)
spaces/{spaceId}                    name, type: personal|household, members[]
spaces/{spaceId}/saves/{saveId}     source_url, platform, creator, caption,
                                    thumb_url, key_frame_url, status, step_text,
                                    language, summary, created_by, created_at
spaces/{spaceId}/saves/{saveId}/items/{itemId}
                                    section, confidence, data{...typed},
                                    user_state (to_try|tried|visited|cooked|done|using|not_useful; the last two added in P1-09 for tools)
spaces/{spaceId}/lists/{listId}     section, name, item_refs[], overrides{} (P1-13: per-exercise edits;
                                    created via POST /v1/spaces/{id}/lists, members edit item_refs/overrides)
```

`items` is queried as a collection group by `section`, so each section tab is one query.

**Spaces and invites (P1-03):** the phone keeps sending `space_id` = `me` or `home`; the backend resolves them through `users/{uid}.spaces`. Spaces and invites are created only by the backend, so a client can never add itself to `members`. An invite link is `https://reelbrain-dev.web.app/join/<code>` on Firebase Hosting (free on Spark): an Android App Link opens the app straight to the join screen, and the page shows the code for typing in.

**Security rules:** a user reads a space only if their uid is in `members`; clients may write only `note`, `user_state` and list membership; everything AI-produced is written by the backend service account. Videos in Storage are deleted when the job ends; key frames live under `frames/{spaceId}/`.

## Phase 0 — Spike: prove the hard part

Gate: 10 real reels (5 TikTok, 5 Instagram) go from share to correct JSON on an Android phone, at $0. No design work in this phase; ugly screens are fine.

- [x] **P0-01 · Repo and skeleton**
  - Monorepo created with the structure in Locked tech spec; Flutter app runs on your phone; FastAPI returns 200 on `/health` locally.
  - GitHub Actions runs lint + tests on every push.
- [x] **P0-02 · Android share intake**
  - Two share targets, "Reelbrain · Me" and "Reelbrain · Home", appear when sharing from TikTok, Instagram and YouTube.
  - Each receives the URL, logs it with the space, and closes in under 1 s without opening the main app.
- [x] **P0-03 · On-device downloader (Android)**
  - Kotlin platform channel wraps youtubedl-android; `download(url) → file path, duration, size`.
  - Downloads succeed for at least 9 of the 10 test reels over home Wi-Fi and mobile data; failures return a clear error code.
  - Runs in a background worker so it survives closing the share sheet.
- [x] **P0-04 · Backend pipeline v0 (local)**
  - `POST /v1/saves` + upload + `/internal/process` working locally with the Gemini key from env.
  - Extract call returns JSON that validates against the Pydantic schema for all 10 reels; ffmpeg saves the key frame at `key_frame_t`.
- [ ] **P0-05 · Deploy to Cloud Run + Cloud Tasks**
  - Backend deployed; Cloud Tasks queue with 3 retries and exponential backoff; 429 from Gemini is retried, not failed.
  - One end-to-end run from the phone to Cloud Run to Firestore.
- [x] **P0-06 · Fallback chain**
  - If the phone can't download, `/no-video` triggers: cloud mirror → yt-dlp → caption-only (`partial`).
  - Each step's outcome logged; caption-only still produces a summary.
- [x] **P0-07 · Spike report**
  - Table in this doc: per reel, download path used, Gemini latency, section detected, correct yes/no.
  - Decision recorded: on-device download confirmed or replaced; Gemini model and real free quota noted.

**Spike report** (24 Oct 2026, Samsung S22 Ultra, local backend on the PC; "Correct?" is my reading, to be confirmed by you)

| # | Platform | Reel | Download path | Gemini s | Sections detected | Status | Correct? |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Instagram | reel/De1aH9Po2ps (Plinth, Arabic) | phone | 297* | tools 0.98 | ready | yes |
| 2 | TikTok | ZSgmg8pkU (VoiceStudio) | phone | 224* | tools 0.95, fact_check 0.85 | ready | yes |
| 3 | TikTok | ZSgm3sUEk (hairline skill) | phone | 22 | tools 1.00 | ready | yes |
| 4 | TikTok | ZSgm3tAkB (AirPods sale, Arabic) | phone | 164 | none | needs_review | yes (products aren't a Phase 1 section) |
| 5 | Instagram | reel/Dezc4qeimex (brag skill) | phone | 29 | tools 0.95 | ready | yes |
| 6 | Instagram | reel/De1HVuyixUW (Aroya cruise, Arabic) | phone | 67 | places 0.95 | ready | yes |
| - | TikTok | ZSgm7onTd | all fallbacks failed | | | failed | video unavailable everywhere (TikTok oEmbed 400) |
| - | Instagram | reel/Ddwj68hNLCA | phone | | | failed | not counted: ran before the Gemini key was set |

\* includes waits on Gemini 503 "high demand" before the model chain existed.

**Gate:** passed by owner decision on 24 Oct with 6 of 10 reels (3 TikTok, 3 Instagram), all correct, all downloaded on the phone, $0 spent. The other 4 were skipped to move on.

- **Decision, on-device download: confirmed.** 6 of 6 working reels downloaded on the phone (Instagram 4.9 to 19.6 MB in 4 to 19 s). The server fallback is only for dead or blocked links. TikTok links yt-dlp can't read come back as `EXTRACTOR` and go to `/no-video`.
- **Gemini models:** `GEMINI_MODELS` = 3.6 Flash, 3.8 Flash, 3.5 Flash-Lite, 3.1 Flash-Lite, tried in order on 429/5xx, for each key in `GEMINI_API_KEYS` (yours, then your wife's). 3.6 Flash answers in 20 to 70 s per reel. 3.8 Flash was overloaded on test day.
- **Free quota seen in AI Studio (24 Oct):** Flash models 5 requests/minute and 20/day each; 3.5 and 3.1 Flash-Lite 15/minute and 500/day each. Gemini calls are spaced 15 s apart. `gemini-2.5-flash` is refused for new keys, and search grounding is 0/day for Gemini 3+ (see the note on Call 2 for P1-08).
- **Still open from Phase 0:** P0-05, the Cloud Run deploy (`infra/deploy.ps1`, which needs your gcloud login and Firebase console steps). Phase 1 can run against the local backend until then. Deploy before P1-06 push notifications and before Phase 2.

## Phase 1 — MVP: five sections on Android

Gate: two weeks of daily use by you on Android (your wife joins in Phase 2 when the iPhone build lands), 85% or more saves filed correctly, nothing lost.

**Foundation**

_24 Oct: P1-01 and P1-02 are deferred by owner decision (the plan was approved, built later). Function first; screens stay plain Material until then._

- [ ] **P1-01 · Design tokens and theme**
  - All colour, type, radius and motion tokens from Design system in `lib/core/theme`; light/dark switch; Plex Sans Arabic loads in RTL.
  - A hidden "Design gallery" screen shows every token and component.
- [ ] **P1-02 · Core components**
  - SaveCard, SectionChip, StatusPill, SkeletonCard, EmptyState, BottomSheet built and shown in the gallery in both themes and both directions.
- [x] **P1-03 · Auth and spaces**
  - Google sign-in; on first launch a personal space is created; "Create household" generates an invite link; joining adds the uid to `members`.
  - Security rules deployed and covered by emulator tests.
  - _Verified 24 Oct on the S22: sign-in, personal space, household created, a Home share processed into the household. Join is covered by backend tests; the second phone (iPhone) joins in Phase 2. The invite page on Firebase Hosting (`hosting/`) is built but not published: it is only needed for the Android App Link, so typed codes are used until iOS Universal Links (P2-02)._
- [x] **P1-04 · Save toast and background upload**
  - Signature save toast (pill, thumbnail, gold check, 1 s); upload continues with the app closed; retry on network loss.
  - _24 Oct: background upload, retry and waiting-while-offline verified on the S22; the share shows a plain "Saving to Me/Home". The styled pill (thumbnail, check) is deferred with P1-01/P1-02._
- [x] **P1-05 · Home feed and processing card**
  - Live list of saves with shimmer and step text while processing; pull to refresh; per-section "to try" counters.
  - _24 Oct, on the S22: feed live from Firestore across Me and Home, processing card with live step text switched to the result by itself, Dev and Tools counter shown._
  - _Note: Design system v2 replaced the shimmer with flat grey bars at the final size; built that way. Items carry `space_id`/`save_id` and saves a `sections` list (backend-written), so counters use one collection-group query per space (rule + index in `infra/`)._
- [x] **P1-06 · Push notifications**
  - FCM message on `ready` with the key result in the text; tapping opens the item; Fact Check notifications carry the verdict line.
  - _24 Oct, on the S22: a TikTok share processed through the tunnel and the phone showed "Tool saved: hairline +1 more" with the summary (the Fact Check verdict line comes with P1-08). Tapping opens the save; also reachable by tapping a feed card. Away from home: `backend/scripts/serve.py` starts a Cloudflare quick tunnel and publishes its address to `config/backend`, and the app follows it._
- [ ] **P1-07 · Inbox and section correction**
  - `needs_review`, `partial` and `failed` saves listed with one-tap filing and retry; corrections call `/section`.
  - _24 Oct: built and tested (backend: re-read with hint, kept video, correction log, retry; app: Inbox with badge, File as chips, Retry, "Wrong section?" on the save screen). Seen live: with both Flash models at 503, 3.5 Flash-Lite filed an AirPods sale ad as Fact Check, which Flash had sent to review; worth watching in P1-17._

**Sections**

- [ ] **P1-08 · Fact Check**
  - Grounded enrich call; claim list with verdict chips and sources; VerdictRing on the card; "Dive deeper" generates an explainer on tap.
  - AI-generated label and checked date always visible.
- [ ] **P1-09 · Dev and Tools**
  - URL verification + GitHub stars/last commit; tool card with copy buttons for snippets; status To try / Tried / Using / Not useful; filter by category.
- [ ] **P1-10 · Recipes**
  - Recipe card, servings scaler, "estimated" markers; grocery list across selected recipes; tags.
- [ ] **P1-11 · Cooking mode**
  - Full-screen steps, swipe navigation, inline timers in a pinned pill, screen stays on, "jump to moment" plays nothing but shows the key frame.
- [ ] **P1-12 · Places + map**
  - Backend Places lookup with a picker when several matches; dark custom map, section-coloured pins, bottom carousel, Visited toggle, lists.
- [ ] **P1-13 · Workouts**
  - Exercise list with a pose frame per exercise (cut at each `t`); edit durations; combine saves into a routine.
- [ ] **P1-14 · Workout mode**
  - Full-screen TimerRing around the pose image; 3-2-1 beep and haptic; auto-advance to rest and next exercise; pause/skip; completion logged.
- [ ] **P1-15 · Library and search**
  - All saves searchable by title, summary, transcript and tool/recipe/place names; filter by platform and section.

**Hardening**

- [ ] **P1-16 · Settings, quotas and cost guard**
  - Language, theme, daily cap of 20 saves, budget alert check.
  - **Gemini key chain** (approved 24 Oct): an ordered list of Gemini API keys in Settings (yours and your wife's, **each from its own Google account**; several projects on one account to stack free quota breaks the Gemini API terms). Each key tries every model before the next. Keys are stored encrypted in Secret Manager by the backend, never on the phone or in Firestore. Each row shows today's use against its free limit.
    - Model order per key: 3.6 Flash → 3.8 Flash → 3.5 Flash-Lite → 3.1 Flash-Lite (free tier, 24 Oct: Flash 20 requests a day each, Flash-Lite 500 a day each). Other providers were dropped: none of them takes a video file.
    - Phase 0 already has the backend half: `GEMINI_API_KEYS` and `GEMINI_MODELS` in `backend/.env`.
- [ ] **P1-17 · Test set regression**
  - Script runs the 20-reel set through the pipeline and prints accuracy per section; must hit 85% before the gate.

## Phase 2 — iPhone and household

Gate: your wife uses it on her iPhone for two weeks and both phones see the same Home space in real time.

- [ ] **P2-01 · iOS build pipeline**
  - Apple Developer account active; signed build uploaded to TestFlight by CI; your wife installed as an internal tester; a reminder to re-upload before the 90-day expiry.
- [ ] **P2-02 · iOS Share Extensions**
  - Two extensions, "Reelbrain · Me" and "Reelbrain · Home"; hand off the URL through an App Group and close in under 1 s.
- [ ] **P2-03 · iOS video fetch**
  - Implement the path chosen in P0-07 (on-device or cloud fallback); 9 of 10 test reels succeed from the iPhone.
- [ ] **P2-04 · Household experience**
  - "Added by" avatar on cards; partner gets a push on new Home saves; Me/Home switch on every section tab.
- [ ] **P2-05 · Lists and sharing**
  - Place lists ("Date night"), recipe collections, workout routines shareable inside the household.
- [ ] **P2-06 · Resurfacing**
  - Weekly digest notification (untried tools, uncooked recipes, unvisited places, unfinished workouts); optional near-me reminder for saved places.
- [ ] **P2-07 · Ask your saves**
  - Chat screen answering questions across saved items, citing the cards it used.
- [ ] **P2-08 · Polish pass**
  - Shared-element transitions, Lottie for save/empty states, haptics review, accessibility labels, reduce-motion support, Arabic copy review.

## Phase 3 — Expand and finish

Gate for "finished": every approved section live, crash-free sessions ≥ 99.5%, and a decision on store release.

- [ ] **P3-01 · Section plug-in framework**
  - A section = schema + prompt + card + detail screen registered in one place; adding one needs no pipeline changes.
- [ ] **P3-02 · Products and Shopping** — product, brand, price, where to buy; wishlist and compare.
- [ ] **P3-03 · Watchlist** — books, movies, series, anime; status and links to tracker apps.
- [ ] **P3-04 · Learn (how-to, DIY)** — steps, tools, materials; checklist mode.
- [ ] **P3-05 · Travel itineraries** — day-by-day stops turned into a map trip.
- [ ] **P3-06 · Money, Career and Health claims** — auto-routed to Fact Check with stronger disclaimers.
- [ ] **P3-07 · Music** — identify the track; open in Spotify or YouTube Music.
- [ ] **P3-08 · Custom sections** — describe a section in a sentence; AI drafts the schema; user approves.
- [ ] **P3-09 · Backlog import and exports** — paste many links; recipes to PDF, tools to Markdown, places to Google Maps.
- [ ] **P3-10 · Offline and performance** — cached cards and frames; cold start under 2 s; image sizes tuned.
- [ ] **P3-11 · Release readiness** — privacy policy, terms-of-service review, `prod` project, store listings and screenshots if you decide to publish.

## Kickoff prompt for Claude Code

Paste this into Claude Code in the empty repo to start P0-01; afterwards, start each session with "Next ticket: P0-0X".

```
You are building Reelbrain, a Flutter + Firebase + FastAPI app that turns shared
TikTok/Instagram/YouTube reels into structured knowledge (Fact Check, Dev and
Tools, Recipes, Places, Workouts). The full PRD and build plan are in
docs/PRD.md and docs/BUILD_PLAN.md. Treat the "Locked tech spec", "Design system",
"AI contract" and "Backend contract" sections as fixed specs.

Working rules:
- Work one ticket at a time, in order. Start with P0-01.
- Before coding, restate the ticket's acceptance checks and your plan.
- Meet the Definition of done in BUILD_PLAN.md before calling a ticket finished.
- Commit with the ticket ID: feat(P0-01): ...
- If a spec must change, propose the change to docs/ first and wait.
- Never commit API keys; use .env files and Secret Manager.
- When done, list what to test on my phone and what's next.

Start now with P0-01: create the monorepo structure, a running Flutter app,
a FastAPI /health endpoint, and GitHub Actions for lint and tests.
```

Copy the PRD and this tab into `docs/PRD.md` and `docs/BUILD_PLAN.md` (export the doc as Markdown) so Claude Code can read them.
