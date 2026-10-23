# Reel-to-Knowledge App — PRD v0.1

Oct 23, 2026 · @Mahmoud Adel

## Summary and vision

Ready to code? The ticket-by-ticket plan lives in Build plan.

Share any reel to the app and it becomes something you can act on: a verified claim, a clickable tool link, a cookable recipe, or a pin on a map. Working title: **Reelbrain** (placeholder, see Open questions).

The app sits in the phone's share sheet. One tap sends a TikTok, Instagram Reel, YouTube Short or Facebook video to it. AI watches the video (audio, on-screen text, caption), decides what kind of content it is, and files it into a smart section with the useful parts already pulled out.

Guiding principles:

- **One tap in, zero typing.** Saving must take under 3 seconds and never leave the source app.
- **Extract the action, not the video.** The saved item is the recipe, the repo link, the verdict or the place. The video is the reference.
- **Cheap by design.** Runs on free tiers for 1 to 5 saves a day; the user can bring their own Gemini key.
- **Honest AI.** Every extracted fact shows where it came from (caption, speech, on-screen text, web search) and how confident the model is.
- **Built for two.** Shared spaces so a couple or household saves into the same recipes and places.

## Problem and target users

People save dozens of useful reels and never return to them, because a saved video is a bookmark, not an answer. The information is locked inside 60 seconds of speech and fast on-screen text, spread across several apps' "Saved" folders, with no search.

| Persona | Saves | Job to be done | Today's pain |
| --- | --- | --- | --- |
| The curious learner (Mahmoud) | Science claims, theories, "did you know" facts | Know if it's true before believing or repeating it | No quick way to fact-check a reel; comments are noise |
| The builder (Mahmoud) | "Use this repo", "try this AI tool", Claude skills, extensions | Get the link and what it does, ready to try later | The link is spoken or flashed on screen, never written; forgotten in Saved |
| The home cook (wife) | Recipe reels | Cook it later with a real ingredient list and steps | Quantities are spoken fast or missing; sent over WhatsApp and lost |
| The explorer (both) | Restaurants, cafes, places to visit | Find it on a map when nearby or planning a day out | Name is half-visible; no address; scattered across chats |

The shared thread: the user wants the *output* of the video, organised by what they will do with it.

## Competitive landscape and differentiation

The "share a reel, AI organises it" space is crowded, but every player is either a single-vertical app or a generic organiser. None fact-checks, and none treats developer tools as a first-class section.

| App | Focus | What it does well | Gap we exploit |
| --- | --- | --- | --- |
| [ReciMe](https://www.recime.app/blog/?p=4309), [Flavorish](https://www.flavorish.ai/blog/save-recipes-from-instagram-tiktok-youtube-facebook) | Recipes only | Clean recipe cards, grocery lists, households | Nothing outside food |
| [Korka](https://mwm.ai/apps/korka-food-map/6762612703), [Triply](https://hunted.space/product/triply-3) | Places only | Venue detection from captions and audio, map pins | Nothing outside places |
| [Ordo](https://www.scriptbyai.com/organize-reels-shorts-ordo/) | General organiser | Background save from share sheet, auto-folders (places, recipes, books, workouts) | iOS only; categorises but doesn't extract actions |
| [Fofo](https://apps.apple.com/us/app/id6738624828), [Trott](https://apps.apple.com/bb/app/trott/id6751728352), [RaqunAI](https://mwm.ai/apps/raqunai/6763550996) | General organiser | Smart categories, search, some enrichment | Subscription-gated; no fact-check; no dev/tool section |
| [ReelSave](https://mwm.ai/apps/reelsave-smart-bookmark/6758552015), [ReelsHub](https://hunted.space/dashboard/reelshub) | Bookmarking | Multi-platform save, collections | Saves the video, not the knowledge |

Our wedge:

1. **Fact Check section** — no competitor verifies claims with cited sources.
2. **Dev and Tools section** — resolves spoken or on-screen repo/tool names into real links with a "what it does" card.
3. **All verticals in one app**, with deep extraction per vertical rather than just a folder label.
4. **Bring-your-own-key / near-zero cost** — no subscription needed for light users.
5. **Couple-first sharing** and **Android support** from day one (Ordo is iOS-only).
6. **Arabic and Egyptian content** handled natively (Gemini transcribes Arabic), a gap for most Western apps.

## Core loop

Every save runs the same five steps; only the last two differ per section.

1. **Share.** User taps Share → Reelbrain in TikTok, Instagram, YouTube, Facebook, X or the browser. A small sheet confirms "Saved" and offers an optional section override and note. The user returns to their feed immediately.
2. **Extract.** The backend fetches the video and its metadata (caption, author, hashtags, thumbnail). Gemini watches the video once and returns one structured JSON: transcript, on-screen text, key frames, language, and a summary.
3. **Classify.** The same call labels the item with one or more sections and a confidence. Low confidence (<0.6) lands in an Inbox for one-tap filing.
4. **Enrich.** Section-specific follow-ups run: web search for fact checks, link resolution for tools, Places lookup for venues, recipe structuring for food.
5. **Act.** The item becomes a card with actions: open repo, start cooking mode, navigate, mark as tried, share to partner.

One video can belong to several sections. A "top 5 cafes in Zamalek" reel yields five place pins; a tutorial that mentions three repos yields three tool cards.

## MVP smart sections

The MVP ships five sections. Each has its own extraction schema, enrichment step and card design.

### 1. Fact Check

Goal: tell the user whether the science in the reel holds up, with sources.

- **Quick verdict first.** Within seconds of processing, the notification itself carries the verdict (e.g. "Mostly accurate: 1 of 3 claims oversimplified") so you get the answer while still watching.
- Split the transcript into individual checkable claims (max 5 per video), ignoring opinions and jokes.
- For each claim: verdict (Accurate · Mostly accurate · Misleading · False · Unverifiable), a one-line correction, and 2 to 3 cited sources from web search grounding. Prefer peer-reviewed, government and encyclopedic sources.
- **Dive deeper (on demand):** a button that generates a longer explainer only when tapped, so the quick verdict stays fast and cheap.
- Always label the result as AI-generated with the date checked; never present an unsourced verdict.

### 2. Dev and Tools (Skills and Tech)

Goal: turn "use this repo" videos into a ready-to-try link.

- Detect every tool, repo, library, website, extension, prompt or Claude/AI skill mentioned in speech, on-screen text or caption.
- Resolve each to a canonical URL (GitHub repo, product site, Chrome Web Store, PyPI/npm page). Verify the link exists before saving.
- Tool card: name, link, one-line "what it does", the specific use the creator showed, category tag (AI, dev tool, productivity, design…), pricing (free / paid / open source), and for GitHub the stars and last-commit date.
- Status per tool: To try · Tried · Using · Not useful.
- Copy-able snippets: install command, prompt text or config shown in the video.

### 3. Recipes

Goal: a cookable recipe from any food reel.

- Merge caption, speech and on-screen text into: title, servings, time, ingredients with quantities and units, numbered steps, and tips.
- Where quantities aren't stated, estimate and mark them "estimated" so the cook knows.
- Metric units by default; Arabic and English ingredient names.
- Step-by-step cooking mode with screen-on, timers and the video clip for each step.
- Grocery list from one or several recipes; tags (dinner, dessert, quick, healthy).

### 4. Places

Goal: every restaurant or place from a reel, on a map.

- Detect venue names, branches, city and neighbourhood from location tags, caption, speech and signage in frames.
- Resolve with Google Places: address, coordinates, rating, hours, phone, price level, Maps link. If several matches, ask the user to pick.
- Store a key-frame screenshot plus "what to order / why go" notes from the video.
- Interactive map with filters (food, cafe, attraction, shopping), "Visited" status and "near me" view.
- Lists such as "Date night" or "Alexandria trip", shareable with a partner.

### 5. Workouts (added to MVP)

Goal: save an exercise reel and later be walked through it, pose by pose, with timers.

- Extract each exercise: name, duration or reps × sets, rest, equipment, form cues, and its timestamp in the video.
- **Pose image:** a key frame cut from the creator's own video at that exercise's timestamp, taken before the video is deleted. Optional 3-second looping clip per exercise for movements a still can't show.
- **Workout mode:** full screen, one exercise at a time: pose image, one cue line, and a big countdown set from the video ("hold for 2 minutes" → 2:00). 3-2-1 beep, then auto-advance to the rest timer and the next exercise. Screen stays on.
- Durations the video doesn't state default to 30 s, marked "estimated" and editable before starting.
- Combine several saves into one routine; log completions; resurface untried workouts in the weekly digest.
- Fallback when no clear frame exists: an illustration from an open exercise database (to be chosen).

### Catch-all: Inbox and Library

Items that fit no section, or that the user wants to keep as plain bookmarks, live in a searchable Library with summary, tags and transcript.

## Enhancements beyond MVP

The aim is to cover "the entirety of the options": the section system is a plug-in, so each new section is a schema, a prompt and a card template.

Decision (23 Oct): all sections below are approved. Workouts moved into the MVP; the rest follow in Phase 3.

### More sections

| Section | Extracts | Key action |
| --- | --- | --- |
| Workouts | Exercises, sets, reps, rest, equipment | Build a routine, workout mode with timers |
| Products and Shopping | Product name, brand, price, where to buy | Price check, wishlist, compare |
| Books, Movies, Series, Anime | Titles, author/studio, why recommended | Watchlist / reading list, link to tracker apps |
| Learn (how-to, life hacks, DIY) | Steps, tools needed, materials | Checklist mode |
| Travel itineraries | Day-by-day stops, tips, budget | Turn into a trip plan on the map |
| Money and Career tips | Advice, claims, numbers | Auto-routed to Fact Check when claims are factual |
| Health and Nutrition claims | Claims, dosages, products | Always fact-checked, with a stronger disclaimer |
| Music | Track and artist from the video's audio | Open in Spotify / YouTube Music |
| Custom sections | User describes a section in one sentence | AI generates the schema |

### Cross-cutting features

- **Ask your saves:** a chat that answers "what was that Python library for PDFs?" or "dinner ideas with chicken from my saves" across everything saved.
- **Smart resurfacing:** a weekly digest of untried tools and uncooked recipes; location reminders when near a saved place.
- **Shared spaces:** a household space for recipes and places; personal space for tools and fact checks. Partner gets a notification on new shared saves.
- **Import backlog:** paste many links at once, or import a TikTok/Instagram data export of past saves.
- **Dedup and merge:** the same place or tool saved twice merges into one card listing both videos.
- **Creator credit:** every card links back to the original creator; optional "creators I trust" score from fact-check history.
- **Export:** recipes to PDF, tools to Markdown/Notion, places to Google Maps lists.
- **Offline:** cards, recipes and screenshots cached for use without internet.

## Key UX flows and screens

The share sheet is the product's front door; everything else is browsing what it produced.

**Flow A — Save (target: under 3 seconds, no app switch)**

1. Share → pick **Reelbrain · Me** or **Reelbrain · Home** in the share sheet. Two separate share targets, so the space is chosen by the tap itself: no extra screen, no questions.
2. The sheet shows a 1-second "Saved" toast and disappears on its own. You are back in TikTok and keep watching.
3. Everything else runs in the background; section is auto-detected. A notification arrives when ready, with the key result inside it (fact-check verdict, recipe title, place name, number of exercises).
4. Wrong section or space? Fix it later from the item card, never during the save.

**Flow B — Review a new item:** notification → item card with the extracted result, the video thumbnail and a "Wrong section?" correction. Corrections are stored to improve future classification prompts.

**Screens**

| Screen | Purpose |
| --- | --- |
| Home | Recent saves feed with processing status, "to try" counters per section, search bar |
| Section tabs | Fact Check, Tools, Recipes, Places (bottom nav); more sections under "All" |
| Item card | Section-specific result, source video, transcript, sources, actions |
| Map | Places with filters, lists and "near me" |
| Cooking mode | Full-screen steps, timers, screen stays on |
| Inbox | Low-confidence or failed items needing one tap |
| Settings | Own Gemini key, language, shared space, notifications, export |

Visual direction (to refine later with design): card-based, each section with its own colour and icon, RTL-ready for Arabic, dark mode.

## Technical architecture and free-tier feasibility

Verdict: a fully cloud setup on free tiers is feasible for 1 to 5 videos a day, with no separate transcription step and no n8n. The AI part is easy; the hard part is getting the video file out of TikTok and Instagram.

&#91;embedded content: architecture · phone, backend, Gemini, enrichment, database\]

If the phone can't fetch a video, the backend falls back to cloud mirror APIs, then caption-only mode (see the options table below).

### AI: Gemini watches the video directly

- Gemini is natively multimodal: it takes the video file (audio and frames together) and can return a transcript, on-screen text, summary and section classification in **one** structured-output call. No need to convert to audio first. Audio and video input go through the Files API, which is required for files above 20 MB ([Gemini audio docs](https://ai.google.dev/gemini-api/docs/audio.md.txt)); most reels are under that.
- YouTube URLs can be passed straight to Gemini without downloading ([docs](https://ai.google.dev/gemini-api/docs/interactions/audio)). TikTok and Instagram URLs cannot; the bytes must be fetched first.
- Free tier: Flash and Flash-Lite models are free; Pro models became paid-only in April 2026 ([AgentDeals](https://agentdeals.dev/gemini-api-pricing-changes)). Google no longer publishes the per-model free quotas and points to AI Studio instead ([DevelopersDigest](https://www.developersdigest.tech/rate-limits/google)); third-party measurements range from about 20 to 1,500 requests a day depending on model ([dev.to](https://dev.to/feed/romeroyang), [TinkerLLM](https://tinkerllm.com/blog/gemini-api-free-tier-limits-rate-quotas/)). At 5 videos × 3 calls = 15 calls a day, even the lowest figure fits.
- Fact Check needs Google Search grounding. Free grounding is reported as available only on gemini-2.5-flash and 2.5-flash-lite (about 500 a day), not on 3.x free tier ([dev.to](https://dev.to/feed/romeroyang)). Plan: use 2.5 Flash for the grounded call; confirm in AI Studio.
- Caveat: on the free tier, content sent may be used to improve Google's products ([YingTu](https://yingtu.ai/en/blog/google-gemini-api-free-tier-limits-2026)). Acceptable for public reels; worth a note in the privacy policy.

### The real problem: fetching the video

TikTok and Instagram block downloads from cloud/datacenter IPs; yt-dlp is reported broken from datacenter IPs for both ([agent-video-downloader](https://pypi.org/project/agent-video-downloader/)). Options, in order of preference:

| Option | How | Pros | Cons |
| --- | --- | --- | --- |
| A. Fetch on the phone (recommended) | The app downloads the video itself using the phone's home/mobile IP, then uploads it to the backend | Free, reliable, no PC needed, residential IP isn't blocked | Needs a native downloader in the app (e.g. yt-dlp packaged for Android); more app work |
| B. Cloud mirror APIs | Backend calls public mirror services (e.g. TikWM) as fallback | No app work | Third-party, can break or vanish any day |
| C. Your PC as worker | yt-dlp + browser cookies on your PC polls the job queue | Very reliable, handles private accounts | PC must be on; the thing you wanted to avoid |
| D. Caption-only mode | Use the platform's public page data/oEmbed for caption and thumbnail only | Always works | No speech or on-screen text; weak for recipes and tools |

Recommended chain: A first, B as fallback, D as last resort, C optional later.

### Backend and hosting (all free tier)

- **API and jobs:** Google Cloud Run. Free each month: 2M requests, 180,000 vCPU-seconds, 360,000 GiB-seconds ([Cloud Run pricing](https://cloud.google.com/run/pricing?hl=cs)). One video job takes well under a minute, so 150 jobs a month uses a tiny fraction.
- **Database, auth, storage, push:** Firebase (Firestore, Auth, Storage, Cloud Messaging) or Supabase. Videos are deleted after processing; only thumbnails and one key frame are kept.
- **Maps:** Google Places API for venue lookup and Maps SDK for the map; check current free monthly usage before launch. OpenStreetMap is the zero-cost fallback.
- **n8n:** not needed. A small Cloud Run service with a job queue is simpler and free. n8n could be used for a quick prototype, but it adds hosting with no gain.
- **Bring your own key:** users can paste their own free Gemini key, so quotas scale per user and the app stays free to run.

### Mobile client

**Decision: Flutter + Firebase**, Android first, iOS right after.

- **Flutter** gives one codebase for Android and your wife's iPhone, has share-intent plugins for both platforms, and is strong at the custom full-screen modes this app needs (cooking mode, workout timers, map).
- **Firebase** over Supabase: push notifications (FCM) are built in, Firestore syncs offline and between both phones, and it lives in the same Google project as Gemini and Cloud Run. Supabase's free projects can pause when idle, which is bad for a background-processing app.
- **Share targets:** Android registers two share activities (Me, Home); iOS gets two Share Extensions with the same labels. Each one only hands off the link and closes.
- **iOS video fetch** is the main unknown: running a downloader inside an iPhone app is harder than on Android. Phase 0 tests it; if it fails, iPhone saves use the cloud fallback chain.

**Getting it onto your wife's iPhone without the App Store:** TestFlight. It needs an Apple Developer Program membership at $99 a year, and she installs the free TestFlight app and accepts an invite or public link ([Expo docs](https://docs.expo.dev/submit/testflight.md), [Analytics Insight](https://www.analyticsinsight.net/app-development/apple-developer-program-membership-costs-and-benefits)). Internal testers get builds immediately, with no review ([Expo docs](https://docs.expo.dev/submit/testflight.md)). Each build stops working 90 days after upload, so a fresh build must be uploaded at least every 3 months ([Drizz](https://www.drizz.dev/post/testflight-access)). iOS builds need a Mac or a cloud build service, which can also automate those uploads.

## Data model

One generic Save record plus one typed Extraction per section keeps new sections cheap to add.

| Entity | Key fields |
| --- | --- |
| User | id, name, language, gemini\_key (encrypted, optional), space\_ids |
| Space | id, name, members, type (personal / shared) |
| Save | id, space\_id, source\_url, platform, creator, caption, thumbnail\_url, key\_frame\_url, transcript, on\_screen\_text, language, summary, status (queued / processing / ready / failed / needs\_review), created\_at |
| Classification | save\_id, section, confidence, user\_corrected |
| FactCheck | save\_id, claims\[ {text, verdict, correction, sources\[\], confidence} \], overall\_score, checked\_at |
| Tool | save\_id, name, url, type, what\_it\_does, use\_shown, pricing, github\_stars, last\_commit, install\_snippet, status |
| Recipe | save\_id, title, servings, total\_time, ingredients\[ {name, qty, unit, estimated} \], steps\[\], tags |
| Place | save\_id, name, place\_id, lat, lng, address, rating, hours, category, notes, visited, list\_ids |
| List | id, space\_id, section, name, item\_ids |

Added for Workouts: **Workout** — save\_id, title, exercises\[ {name, duration\_s or reps, sets, rest\_s, pose\_frame\_url, clip\_url, cues, estimated} \], total\_time, equipment, completions\[\]. Space is set by the share target used (Me → personal, Home → household).

## Non-functional requirements

The app must stay free to run, fail gracefully, and never present a guess as a fact.

- **Latency:** share sheet closes in under 2 s; a result is ready within 60 s for a 90-second reel (p90).
- **Cost guardrails:** per-user daily cap (default 20 saves); retry with exponential backoff on Gemini 429 errors; a queue so bursts wait instead of failing; switch to Flash-Lite when Flash quota runs out.
- **Graceful degradation:** if the video can't be fetched, save caption-only and mark it "partial"; if AI fails, keep the link in Inbox with a retry button. Nothing the user shares is ever lost.
- **Privacy:** videos deleted after processing; only thumbnails, one key frame and extracted text stored. User keys encrypted at rest. Clear notice that free-tier Gemini may use submitted content.
- **Accuracy and trust:** fact checks always cite sources and show a date; health and finance claims carry a stronger disclaimer; tool links are verified to resolve before saving.
- **Platform terms:** downloading platform videos may conflict with TikTok and Instagram terms of service. Keep it personal-use, process transiently, never redistribute video, always credit and link the creator. Revisit before any public launch.
- **Localisation:** Arabic and English UI, RTL layout, and extraction from Arabic (including Egyptian dialect) videos.

## Phased roadmap

Phase 0 de-risks video fetching before any UI work, because that is the one part that could force a design change.

&#91;embedded content: roadmap · 4 phases, 3 gates\]

Each gate must pass before the next phase starts; Phase 1 (highlighted) is the first version you and your wife use daily.

## Success metrics

The app works if saved reels turn into things actually done.

| Metric | Target (personal MVP) |
| --- | --- |
| Saves fully processed (video, not caption-only) | ≥ 90% |
| Correct auto-section without user correction | ≥ 85% |
| Tool links that resolve to the right tool | ≥ 95% |
| Recipes cooked or places visited from saves, per month | ≥ 4 |
| Running cost at 5 saves/day | $0 |
| Time from share to ready result | ≤ 60 s p90 |

## Decisions and open questions

Decided on 23 Oct:

| Topic | Decision |
| --- | --- |
| Platform | Android first for testing; iOS needed soon since your wife uses an iPhone |
| Audience | Personal tool for the two of you for now; store release undecided |
| iPhone install | TestFlight ($99/year Apple Developer membership), builds refreshed every 90 days |
| Spaces | Two share targets, Me and Home; no choice screen, sheet disappears instantly |
| Fact Check | Quick verdict by default, "dive deeper" only on tap |
| Sections | All approved; Workouts with guided pose + timer mode joins the MVP |
| Name | Reelbrain for now, revisit later |
| Stack | Flutter + Firebase + Cloud Run + Gemini |

Still open:

- [ ] When to pay the $99 Apple fee: start of Phase 1, or only once the Android version proves itself?
- [ ] iOS on-device download: confirmed or replaced in the Phase 0 spike.
- [ ] Which exercise image source to use as fallback when no clear frame exists.
