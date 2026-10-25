# Design v4 (Realbrain): proposal, 25 Oct

Status: **approved 25 Oct.** Step 1 (foundation) built 25 Oct; steps 2–6 to come.
Board: https://claude.ai/artifact/5MJRG2CH9syMBU9PfGVg3J (private). Source: Mahmoud's concept board
(10 screens) and the redesign brief. If approved, this replaces `BRAND.md` (Darkroom) and the visual
parts of `DESIGN_V3_PROPOSAL.md` (liquid glass); the PRD gains the features in §4.

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
