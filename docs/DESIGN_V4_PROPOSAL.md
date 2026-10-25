# Design v4 (Realbrain): proposal, 25 Oct

Status: **approved 25 Oct.** Step 1 (foundation) built 25 Oct (88b3bb1). **Revision 2 approved 25 Oct;
step 1b built.** Steps 2, 3 and 4 built 25 Oct; steps 5–6 to come.
Board: https://claude.ai/artifact/5MJRG2CH9syMBU9PfGVg3J (private). Source: Mahmoud's concept board
(10 screens) and the redesign brief. If approved, this replaces `BRAND.md` (Darkroom) and the visual
parts of `DESIGN_V3_PROPOSAL.md` (liquid glass); the PRD gains the features in §4.

## Revision 2: Design 1 structure, Design 2 accents (approved 25 Oct)

Source: Mahmoud's two boards and the "Premium UI/UX Design Direction" brief. **Design 1** (the
flatter charcoal board) sets about 80%: structure, density, cards, buttons. **Design 2** (the first
concept, the navy one with orbs) gives about 20%: the luminous network motif, used only on
onboarding, Threads and Year in Brain. Rule: *keep the interface quiet, make the intelligence
visible, let the memories bring the colour.* Where this revision and the sections below differ,
this revision wins.

**What changes from the approved v4 (and from step 1, already built):**

| Area | Approved v4 / built in step 1 | Revision 2 |
| --- | --- | --- |
| Ground | Navy #080A14 with a lavender haze on every screen | Near-black charcoal, neutral: ground #0E0F12, surface #16181C, raised #1E2126, line #2A2D33. **No haze on everyday screens**; it stays only on onboarding/sign-in, Threads and Year in Brain |
| Text | Pure white / #A7ACBF | Soft white #ECEDEF / cool grey #9A9EA6 (both ≥ 4.5:1 on surface) |
| Accents | Seven bright interest hues | Four restrained accents carry meaning: violet #9C8CFF, blue #6EA2FF, teal #4FD1B9, amber #F2B866. Interests map onto them (Tools blue, Learning/Fact Check violet, Places teal, Recipes amber); Workouts get green #8CCB7A, Ideas yellow #E8CD6B. They show only as a small icon or dot, never as a card fill |
| Cards | Corner colour wash on every Ready card | Plain dark surface, 1 px line, no wash. The photo is the colour (the memories provide it) |
| Buttons | White-to-lavender pill; orange-to-pink main action | One **soft-white pill** for every action (Cook now, Start cooking with its icon). Gradients only where they mean something: the **+** capture button (violet to blue), the selected Threads node, and Year in Brain |
| Stat tiles | Gradient fill | Flat surface: **New items · Memories · To revisit** |
| Greeting line | "Your brain has N things waiting." | "Your brain found N things worth your attention." |
| Tab bar | Brain · Memories · + · Recall · Threads | **Home** · Memories · + · Recall · Threads (Home keeps the brain mark as its icon); outline icons, white active state, no colour |
| Memory detail | One layout | **Per-type layouts.** The photo goes edge to edge at the top with back and bookmark on it, then "From Instagram · Saved 12 Apr", icon chips (Quick, Easy, 12 min), the section's own content, the white action, **Why you saved this**, a row of related memories, and Share · Save · More at the bottom. Recipes show ingredients and steps, tools show the link and what it does, places show the map, workouts the plan, fact checks the claims |
| Recall | Flat list | Grouped **Today · This week · Upcoming**, each card saying why it's back ("3 months ago you saved…, you never tried it") with one action |
| Inbox | Card list | Compact rows: source icon (Instagram, TikTok, YouTube, link, image), title, type · length, a subtle "Processing…" or what it needs, with filter chips **All · Links · Videos · Images** |
| Create | Paste a link | A preview of the input, then **What is this?** (Recipe, Tool, Idea, Learn, Action, Inspiration). The pick is a real section hint sent with the save; leave it on Auto and the AI decides |
| Brain Boosts | "Signals", two lines on Home | Its own calm screen, reached from Home: a few insight cards with small dot-row progress ("Your cooking brain grew this week, +3"), no badges or streaks |
| Onboarding | Mark and text | Design 2's motif, made ours: the polygonal brain glowing softly in the centre, two thin orbital paths, and a few of the user's own memory thumbnails as nodes on them, joined by fine lines. Then Save anything · Turn it into something · Get it back when it matters, and **Get Started** |
| Threads | Constellation (step 5) | The signature screen and the brightest one: **You** in the centre, interests as softly glowing nodes in their accent, thin lines. Tap one to see its tags, its memories, and *why* they connect (the shared tags) |
| Year in Brain | Story screens | The most expressive screen: atmospheric imagery, big numbers, richer gradients, **Share your brain** |

**Unchanged:** the name, Inter, the polygonal brain mark (D7 below), the five destinations, the
Memories tab holding All · Search · Map · Reels, and the build order (the revision is folded into it).

**D7. Logo.** Design 1's corner icon is a two-lobe line brain, not the polygonal one approved
earlier today. Proposal: keep the polygonal brain. It's built, and its nodes and lines are the same
motif as Threads and onboarding. Say if you want the line brain instead.

**Build order with the revision:**

| Step | Builds |
| --- | --- |
| 1b (new, small) | Apply the revision to what step 1 built: charcoal tokens, haze only where it belongs, washes off, one white pill, tab label Home, the new greeting line |
| 2 | Memory detail per type, the Inbox rows, Ready cards in Design 1's layout |
| 3 | Create with its type picker, then Onboarding with the orbital motif |
| 4 | Recall groups with reasons, plus Brain Boosts |
| 5 | Threads |
| 6 | Year in Brain, then store screenshots |

---

**Idea.** The part of your brain that never forgets. Every save moves through **Capture** (I found
something) → **Understand** (Realbrain knows what it is) → **Activate** (I actually use it).

**The concept image is the reference for the look.** Where the written brief and the image
disagree (the brief bans glows and gradients; the image uses soft haze, gradient buttons and
tinted cards), the image wins, as the board shows. What stays banned from the brief: glowing
planets and orbs, particles, neon, holograms.

## 1. Decisions

| # | Question | Proposal |
| --- | --- | --- |
| D1 | Rename **Reelbrain → Realbrain**? | Yes: app name, wordmark, share targets ("Realbrain · Me / Home"). The package id stays (changing it means a reinstall and lost local data). |
| D2 | Drop Darkroom (red safelight, Glow icon, liquid shader, develop effect)? | Yes, all deleted. The brain comes back as the new polygonal mark (§3). |
| D3 | Glass? | No frosted glass. Depth comes from the navy haze behind everything and a soft colour wash in each card's corner. The morphing liquid pill goes; the tab bar is plain. |
| D4 | "Why you saved it", with sharing still one tap? | The AI writes a one-line "Good for…" guess, shown under **Why you saved this**. Tap it to put it in your own words (the existing `note`). There's no question at share time. |
| D5 | **Create** (a link, a typed idea or a photo inside the app) | Links and ideas first (they reuse the caption-only path), photos second. |
| D6 | **Year in Brain** | Build it in December. |

## 2. Design system (as on the board)

**Colour.** Dark is the hero; light is kept because the definition of done requires it.

| Token | Dark | Light |
| --- | --- | --- |
| ground | #080A14 + navy haze (radial #1B1F3D top right, #141A33 bottom left) | #F4F4FA |
| surface (cards) | #111528, with a corner wash in the card's interest hue at ~20% | #FFFFFF |
| raised | #1A1F38 | #ECEBF6 |
| line | white at 7–10% | #DAD9E8 |
| text / muted | #FFFFFF / #A7ACBF | #0E1024 / #5B5F75 |

**Buttons:**

| Button | Look | Used for |
| --- | --- | --- |
| Pill | White to lavender gradient (#FFFFFF → #E6E2FF), ink label | Cook now, Try now, Open map, the + button |
| Main action | Orange to pink gradient (#FF9A5A → #FF6B8B) | One per screen at most, e.g. Start cooking |
| Quiet | Surface fill, 1 px line | Not now, secondary actions |

**Interest hues** (chip dot, card wash, thread node). Light-theme values are darkened to ≥ 4.5:1 when built.

| Interest (section) | Hue |
| --- | --- |
| AI and Tools (`tools`) | #8FB8FF |
| Food (`recipe`) | #FFB27A |
| Fitness (`workout`) | #9BE38A |
| Learning | #9C8CFF |
| Ideas (new) | #FFD66B |
| Travel (`places`) | #6FE0C8 |
| Fact Check (`fact_check`) | #FF6B8B |

Verdict colours stay, on fact-check pills only.

**Type.** **Inter** for Latin and **IBM Plex Sans Arabic** for Arabic; Readex Pro and Plex Sans (Latin) are removed. The scale:

| Style | Size |
| --- | --- |
| Large title | 28 |
| Section | 19 |
| Card title | 16 |
| Body | 15 |
| Meta | 12–13 |

**Shape and motion.**
- Cards are 20 px radius; stat tiles 18; photos inside cards 14; pills fully round.
- Springs run 300–500 ms. Pressing a card scales it to 0.98 with a light haptic.
- Everything stays still with Remove animations on.

## 3. Brand mark: polygonal brain

A side-view brain drawn as a low-poly wireframe:
- The outline is 18 nodes joined by straight lines.
- Inside, 13 more nodes are joined into triangles.
- Seven nodes are drawn larger, and a faint second layer of dots and lines adds depth.

It carries the app's meaning: every point is a save, every line is a Thread.

| Size | Form |
| --- | --- |
| ≥ 96 px (store icon, splash, onboarding) | Full mesh |
| ≤ 60 px (launcher, tab bar, wordmark) | Simplified: the outline and 6 nodes, with thicker lines |
| Android themed icon | One colour, ink on light |

- **Launcher:** the mark sits on a navy tile with a soft lavender haze.
- **Splash:** the full mesh draws in once: the outline first, then the lines, then the nodes, over about 800 ms.
- **In the app:** it's drawn in code from one list of points, so every size stays exactly in sync.

## 4. Navigation and screens

**Tab bar.** It has 5 slots with labels and thin line icons:

| Slot | Icon |
| --- | --- |
| **Brain** | The simplified mark |
| **Memories** | Stacked cards |
| **+** | White pill circle |
| **Recall** | Circular arrow |
| **Threads** | Connected nodes |

Today's Search, Map and Reels views move inside Memories, and the Inbox is reached from Brain.

| Screen | Today | v4 |
| --- | --- | --- |
| **Onboarding** (4) | Sign-in only | **New:** the logo, "What do you save?" (seeds Threads and the Home order), "What happens after you save?" (sets how often Recall nudges), a reel turning into a memory card, then sign-in |
| **Brain (Home)** | Section lanes | **Changed:** "Good evening, Mahmoud" + "Your brain has 37 things waiting.", three stat tiles (**Ready now · Memories · To revisit**), then **Ready for you**: photo cards with a hue wash, interest, title, meta and a pill action. Signals (at most 2) follow below. |
| **Memory card** | Save detail | **Changed:** back; an interest pill with a bookmark; the rounded photo; the title; chips (difficulty, time, serves); the section's content (ingredients, steps, claims…); the main action (gradient); **Why you saved this** with View original; a bottom bar with **Share · Done/Cooked · More**. Memory DNA (impact, related memories) sits under More, not on its own screen. |
| **Inbox** | Low-confidence + failed | **Changed:** everything new enters here, with *New / Processing* tabs and states *Processing → Understanding → Ready*. |
| **Create** | None | **New:** paste a link, type an idea, later add a photo; the AI files it like a share |
| **Recall** | None | **New:** "You saved this 47 days ago. Still interested?" with **Try now / Not now / Archive**; a daily server job and "Remember this?" pushes |
| **Threads** | None | **New:** you in the centre, interests around you as hued nodes, tag clusters inside; built on the phone from the existing tags and sections; nodes fade in |
| **Signals** | None | **New**, on Brain: e.g. "You saved 14 recipes and cooked 3", from counts and tried states |
| **Year in Brain** | None | **New**, December (D6) |
| **Store screenshots** | None | At store launch: the brief's 6 headlines |

**Copy changes:**
- "Saved" becomes **"Added to your brain"**.
- Notifications open with **"Remember this?"**.
- Processing reads **"Understanding…"**.

## 5. Backend changes

1. Extract gains `good_for` (≤ 60 chars), `effort_min`, `difficulty` and `impact`, in the same call at no extra cost.
2. `POST /v1/saves` accepts a typed idea or an article link (D5).
3. A daily Recall job and FCM push notifications (free).
4. Ideas becomes a section (title, idea, next steps).

## 6. Build order (one ticket each, each shippable)

1. **Foundation:** tokens, haze background, Inter, the polygonal mark (launcher, splash, tab), the
   5-slot tab bar, every existing screen restyled. Darkroom and the liquid shader are deleted. No backend change.
2. **Brain (Home) + Memory card + Inbox states**, with backend fields 5.1.
3. **Create** (links and ideas) and **Onboarding**.
4. **Recall + Signals.**
5. **Threads.**
6. **Year in Brain** (December), then **store screenshots** at launch.
