# Realbrain V5: audit, strategy and design system

Status: built 3 Nov 2026 on `claude/zealous-edison-23h0cc`. Replaces the visual and navigation parts of
`DESIGN_V4_PROPOSAL.md` (and through it v3 and Darkroom). The PRD, AI contract and backend contract
stay; their V5 additions are listed in §6.

---

## 1. Audit (what was there on 3 Nov)

**Stack.** Flutter client (`app/`, ~8.8k lines, 76 tests, analyze clean), FastAPI backend on an
Oracle VM (`backend/`), Firestore for data and live status, Gemini for extraction, OSM for maps,
Android share targets (*Realbrain · Me / Home*) and an iPhone web app + Shortcut.

### 1.1 Feature inventory

| Area | State | Notes |
| --- | --- | --- |
| Share into Realbrain (Android Me/Home, iOS Shortcut) | **Works** | Native, under 1 s, background upload, retries. Untouched by V5. |
| Paste a link / type an idea (Create) | Works, heavy UX | Full screen; Link/Idea switch, a 7-tile "What is this?" grid, space switch. Seven decisions for a one-tap job. |
| Processing pipeline (fetch → Gemini → frames → enrich) | **Works** | Frame cut at every extracted moment (steps, exercises, claims, tools, places); key frame prompt avoids talking heads. |
| Six sections: Fact Check, Tools, Recipes, Places, Workouts, Ideas | Works | Rich extraction: verdicts + sources, GitHub stars, servings scaler, cooking mode with timers, workout mode with timers, OSM map. |
| Home (v4 "Brain") | Works, poor UX | Greeting, 3 stat tiles, a Boosts card, an Inbox card, "Ready for you" (every untried item), then one 292 px carousel per section. Six patterns of equal weight; the same items appear 2-3 times. |
| Memories tab (All / Search / Map / Reels) | Works, poorly discoverable | Search, the map and the viewer are segments inside one tab; Search pops the keyboard on switch. |
| Section screens | Works, inconsistent | Raw Material chips and checkboxes; every card embeds the full recipe or workout, so lists are enormous; grocery list and routines hidden behind per-card checkboxes. |
| Memory detail | Works | Good bones (frame, chips, section body, Why you saved this, related). Status only in a bottom bar. |
| Reels viewer | Works, incomplete | Vertical swipe + moments sideways. No "done", no "up next", content is overlaid text. |
| Recall (tab) + daily push | Works | Good rules; a whole tab for what is really a Home shelf. |
| Brain Boosts, Threads | Works, low value | Dots and a constellation; no sense of progress. |
| Household space, invites | Works, hidden | One household per user, under avatar → Spaces. Link or typed code. No shared activity at all. |
| Inbox (processing queue) | Works | Reached from a Home card. |
| Phone queue | Works (debug) | Developer list under the avatar menu. |
| Settings | Works, mixed audience | Language, theme, Recall push, Shortcut, **and** Gemini models and usage. |
| Puzzle, levels, achievements, recaps | **Missing** | Described in the V5 brief as existing; not in the repo. |
| Groups (several groups, wall, plans, RSVP, cook-this, challenges, comments, likes, photos) | **Missing** | Only the single household space exists. |
| Home "one thing now" + shelves (Left off, Not tried, Recent, From groups, Revisit) | **Missing** | Ready list + lanes instead. |
| Library dial | **Missing** | No dial exists; the segmented Memories tab is the closest thing. |
| Entertainment (movies, series, books), Products | **Missing** | The extract prompt explicitly drops product videos ("products come in a later version"). |
| "Explored" tracking | **Missing** | Only `user_state` (done/not done); nothing records that you opened or viewed something. |

### 1.2 Information architecture (v4)

`Home · Memories (All | Search | Map | Reels) · + · Recall · Threads`, with Settings, Spaces and the
Phone queue under the avatar, Inbox and Boosts as Home cards, and section screens from lane
headers. Navigation mirrors backend entities (saves, the recall job, the topic graph), not what a
person wants to do.

### 1.3 Root causes (not symptoms)

1. **Revision churn without consolidation.** v2 → v3 glass → Darkroom → v4 → v4 rev 2 shipped in three
   days. Each layer left a pattern behind (v2 moment strip, v3 lanes, v4 Ready cards), so Home stacks
   them all with equal weight and no hierarchy.
2. **Organised around data, not jobs.** People come to *do something now*, *find something*, *do it
   with someone*, *see what they've become*. The tabs answer "list my saves", "show the recall
   queue", "draw my topics".
3. **No ownable visual language.** Charcoal card + 1 px line + white pill, applied to everything, plus
   stock Material widgets on secondary screens. The only identity is a 24 px polygon.
4. **Important actions buried.** Status changes, the grocery list, routines, invites, the map and the
   viewer all sit two or three levels deep or behind modes.
5. **Two UIs for the same item.** Section lists render items one way, the detail screen another.
6. **Categories hard-coded in 10+ maps** across Dart and Python (labels, icons, kinds, actions,
   statuses, interests, create kinds, recall lines, boost nouns, backend names), so adding
   Products or Entertainment was expensive and never happened.
7. **States are an afterthought.** Raw exceptions in error text, text-only empties, spinners.

### 1.4 Constraints that shape V5

* Firestore rules let clients write only `note`, `user_state`, `recall_after` and list fields;
  everything else goes through the backend. New writes need rules changes (+ emulator tests).
* No Storage bucket (Spark plan): frames live on the VM disk behind unguessable paths. Photos
  for group proofs use the same route.
* `api()` is a JSON method channel (Kotlin on Android, fetch on web). Binary uploads go as base64
  JSON; no new native upload path.
* Gemini free tier: no extra calls per save. New categories ride in the same Extract call.
* The S22 (360 × 780 dp, 3×) is the primary device; the iPhone uses the web build.

---

## 2. Strategy

### 2.1 Design philosophy

**Every discovery is a specimen worth using.** Realbrain is a personal *field guide*: it collects
what you find, classifies it, and puts it in your hand at the right moment. Three rules follow:

1. *One thing first.* Each screen leads with the single most useful thing (the pick, the search box,
   the next item, the open plan) and lets everything else recede.
2. *The content is the colour.* Real frames from the reels carry the imagery; the chrome stays
   ink and paper. Category pigments appear as small marks, never as fills.
3. *Actions live on the thing.* Done, plan, cook, share-to-group sit on the item where you see it,
   not behind modes or menus.

### 2.2 Creative direction: "The Curiosity Archive"

A **modern natural-history editorial**: the calm authority of a museum catalogue and a field guide
(specimen labels, catalogue numbers, engraved line plates), set with contemporary magazine
typography on an ink-and-paper ground. Nostalgia comes from print artefacts, never from
skeuomorphism: no paper curls, no tape, no scrapbook.

Signature elements:

* **The catalogue label.** Every item carries a mono label: glyph · `No. 0142` · category · source.
  The number is the item's place in your collection (it counts up as you save), so it is data, and
  it turns a feed of bookmarks into a collection of objects.
* **Plates.** Category glyphs drawn as fine engraved line art; small as icons, large in headers and
  empty states, and as the *specimen card* when a save has no frame (typed ideas, books, products
  from a link): typeset title on pigment-tinted paper.
* **The brain and the piece.** The mark is a line-drawn brain whose parietal lobe is a jigsaw piece in
  saffron. Every completed discovery is a piece; My Brain is where the picture fills in.
* **Hudhud, the scout.** The mascot is a hoopoe drawn as a natural-history plate: the bird that, in
  the Qur'anic story of Solomon and in Attar's *Conference of the Birds*, flies out and returns with
  knowledge. Common in Cairo gardens; its cinnamon plumage is the brand saffron. It appears on
  onboarding, empty states, loading and achievements, never as a chatty assistant.

Alternatives considered: *Magazine issue* (strong for recipes and places, weak for tools and
progress), *Card catalogue* (on-theme but too literal, drifts into scrapbook), *Observatory/
constellation* (what v4 tried; reads as generic AI). The archive keeps the magazine's typography and
the catalogue's numbering without either one's literalism.

### 2.3 Brand identity

| Element | Spec |
| --- | --- |
| Mark | Line brain (outline, stem, 3-5 sulci) + saffron parietal piece. ≥ 56 px full; ≤ 32 px outline + piece only. "Arriving" variant: piece lifted 3 units with its socket dashed (splash, success). |
| Wordmark | *Realbrain* in Fraunces SemiBold, -2% tracking, next to the mark. |
| Mascot | Hoopoe, ink line + cinnamon fill, striped wings. Poses: perched, curious (empty), carrying the piece (success/onboarding), reading (loading). |
| Glyphs | 24-unit line icons, 1.6 stroke, round caps: pot, kettlebell, folded map, terminal, scales, bulb, ticket (clapper/TV/book for sub-kinds), price tag. |
| Texture | Fine grain over the ground (≤ 3% opacity), one cached shader; off with reduced motion and transparency. |

### 2.4 Information architecture

Categories are a registry (`lib/core/categories.dart` + `backend/app/schemas`), grouped so the
library stays simple as it grows:

| Category (id) | Shown as | Sub-kinds | Stamps (user_state) |
| --- | --- | --- | --- |
| recipe | Recipes | | To cook → **Cooked** |
| workout | Workouts | | To do → **Done** |
| places | Places | | To visit → **Visited** |
| tools | Tools | repo, app, site, CLI… | To try → Trying (`using`) → **Tried** · Not useful |
| fact_check | Fact checks | | To read → **Read** (`done`) |
| ideas | Ideas | | Open → **Acted on** (`done`) |
| entertainment | Watch & Read | movie, series, book | Want to → In progress → **Finished** (`done`) |
| products | Products | | Interested → Compared → **Purchased** · Not for me |

### 2.5 Navigation

`Today · Library · ( + ) · Groups · My Brain`, five thumb-reach slots with capture in the centre.

* **Today**: the pick for right now, then five shelves with different shapes (not five
  carousels): *Left off* (bookmarks), *Not tried yet* (2 × 2 plate grid), *From your groups* (wall
  excerpts), *Recently saved* (numbered catalogue rows), *Worth revisiting* (one card with Not now /
  Archive). A processing strip at the top replaces the Inbox card.
* **Library**: search first (everything, Arabic-normalised), then the *index* (categories as
  catalogue drawers with counts and what's open), collections, and a status filter. Category pages
  have their own filters (tags, tool kinds, Movies/Series/Books, product status), the map for places,
  grocery list and routines as visible actions.
* **Viewer**: full-screen vertical browse through whatever list you opened it from, with a
  category-specific panel, moments sideways, *Done* that snaps a piece into the brain, and
  *Up next*.
* **Groups**: your groups, each with a **Wall** (shares, plans, cook-alongs, challenges, comments,
  likes, photos), a shared **Library**, **Plans** (upcoming, RSVP, add to calendar) and **Members**
  (invite by QR, link or code).
* **My Brain**: the puzzle (hideable), level, discoveries by category, achievements (shareable
  card), the monthly recap, insights and threads. Recall's rules power *Worth revisiting*.

Moved: Inbox → the processing strip and Library; Phone queue → Settings › Diagnostics; Gemini usage
→ Settings › Usage; Spaces → Groups; Map → Library › Places; Reels → Viewer.

### 2.6 Key UX changes

1. Today leads with one recommendation and *says why* ("Thursday evening, a 25-minute dinner you
   saved 3 days ago"), with *Not now* and *Another* on the card.
2. Status is a stamp on every item surface (card, viewer, detail) with the category's own words.
3. Opening something records it as *explored* (`seen.{uid}`), which powers *Left off* and partial
   puzzle credit; finishing it places the piece.
4. Capture is a sheet: clipboard link pre-filled, one *Save* button; kind and group are optional.
5. Share-to-group from any item; the group gets a copy in its library and a post on its wall.
6. One item component family: the same label, title, stamp and actions in lists, viewer and detail.
7. Errors in plain language with a retry; empties with the mascot and one action; loading in the
   final layout with the mark working.

### 2.7 Design system (tokens in `lib/core/theme/tokens.dart`)

**Colour.** Dark *Ink* (hero, evenings) and light *Paper*; cooking mode stays light.

| Token | Ink (dark) | Paper (light) |
| --- | --- | --- |
| ground | #121110 | #F3EEE5 |
| surface | #1B1917 | #FBF8F2 |
| raised | #25221F | #EAE3D6 |
| line | #35312C | #D9D0C1 |
| text | #F2ECE1 | #1A1714 |
| muted | #B3AA9C | #5D564C |
| faint | #958C7F | #6B6358 |
| saffron (brand fill) | #F0A53A | #E39B2C |
| on saffron | #1A1206 | #1A1206 |
| saffron as text | #F0A53A | #8F5A00 |

Pigments (dark / light): recipe #E57B45 / #A6481C · workout #9BBE5C / #4D6E1C · places #46B8A8 /
#12766A · tools #68A8F0 / #2462B0 · fact_check #A991FF / #5B47C4 · ideas #E2D35E / #786800 ·
entertainment #CF86D9 / #84368F · products #E88AA0 / #A23A5A. Verdicts keep green / amber / red.

**Type.** Fraunces (display: 34 / 28 / 22 / 18, SemiBold, -1.5% tracking; italic for the human
voice), IBM Plex Sans (UI and reading: 17 / 15 / 13), IBM Plex Mono (labels, numbers, timers:
11-12, +8% tracking, caps), Markazi Text for Arabic display, IBM Plex Sans Arabic for Arabic text.

**Space and shape.** 4 pt grid, 20 side gutter, 48 dp targets. Radii: 4 labels and photos inside
cards, 10 cards, 16 sheets, pills for buttons. Separation by rules (hairlines) and tone, not
shadows; shadows only on what floats.

**Components.** CatalogLabel, Stamp (status), RbButton (primary saffron pill, secondary outline,
quiet), Plate/Frame (photo or specimen card), ShelfHeader (numeral + title + see all), ItemRow /
ItemTile / FeatureCard, FilterChips, SearchField, RbSheet, AvatarStack, EmptyState (mascot),
LoadingMark, ErrorNote, Toast, NavBar, PuzzleBrain.

**Motion.** 150-300 ms; springs only on things that answer a touch. Signature moments: the piece
snapping into the brain on *Done* (with a haptic), the mark drawing itself at start, the viewer's
image settling as you swipe. Everything collapses to fades under reduced motion.

### 2.8 Priorities (build order)

1. Foundation: fonts, tokens, theme, art (mark, glyphs, hoopoe, puzzle), components, gallery.
2. Data layer behind an interface (Firestore + in-memory demo for tests and previews).
3. Today, Library, item detail, viewer (the daily loop).
4. Backend: Entertainment + Products sections, `seen`, new stamps, groups, posts, comments, photos.
5. Groups and My Brain.
6. Capture, Inbox, Settings, sign-in; cooking/workout modes restyled.
7. QA on S22 size, both themes, RTL; screenshots.

---

## 3. What changed in the contracts (V5)

See §6 of this file once built (kept current with the code).
