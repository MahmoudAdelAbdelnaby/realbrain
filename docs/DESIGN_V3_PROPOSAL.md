# Design system v3 (liquid): proposal, 25 Oct

Status: **approved 25 Oct**, being built in the 7 steps below. Replaces parts of "Design system (v2)" in
`BUILD_PLAN.md`.

Asked for: a liquid design, organised into sections, with very fluid motion. Built with the
frontend-design and Taste skills.

**Design read:** a phone app for two people who save reels in the evening. The look is liquid
glass on top of the reels' own colours, the home screen is organised by section, and motion runs
on springs. It keeps the Material 3 structure (system Back, insets, accessibility) and adds custom
glass chrome on top. This is an approximation of Apple's Liquid Glass, not Apple's own material,
which only exists in Apple's SDKs.

**Dials:** variance 6 (a product UI, not a landing page), motion 7, density 4.

## 1. The one bold thing: the liquid pill

A floating glass pill sits at the bottom of every screen. It is the navigation bar, and it changes
shape when something happens:

| Moment | The pill becomes |
| --- | --- |
| Browsing | 4 destinations: **Home · Search · Map · Inbox** (Inbox shows a count) |
| A share is processing | It stretches to show the reel's thumbnail and the live step ("Watching the video"); tap to open |
| A save is ready | It flashes the result ("Recipe · Koshari, 35 min"), then settles back |
| Cooking or workout mode | It becomes the timer (digits, pause, skip), pinned while you swipe |

The change is a spring morph of width, height and content (a shared-element style transition).
It is the app's signature, and everything else stays quiet so it stands out.
Android's share pill (shown over TikTok) uses the same glass, through the system's blur-behind
window on Android 12 and later, and a solid pill below that.

## 2. Material: glass on what floats, solid under what you read

Glass needs colour behind it, and text on glass loses contrast. So:

- **Glass:** the pill, the top bar once content scrolls under it, bottom sheets, menus, the map
  carousel cards, and the cooking and workout controls.
- **Solid:** cards, lists, everything you read for more than a glance.
- **Recipe (Flutter):** `BackdropFilter` blur 24 with saturation boosted 1.6×; fill white at 14%
  (light theme) or ground at 55% (dark theme); a 1 px inner highlight on the top edge (white at
  35%/18%); a 1 px outer line; one soft shadow tinted to the ground colour. Text on glass uses
  `text`, never `muted`.
- **Fallback:** when the phone has high contrast or reduced motion on, glass becomes a solid
  `raised` fill with the same shape.
- **Cost:** at most 2 blurred layers on screen at once (pill + top bar, or a sheet). Checked for
  steady 60/120 fps on the S22.

**Colour behind the glass:** the home screen's background is a very dim, heavily blurred wash of
the newest save's key frame, so the glass picks up the reels' own colour. This adds no new
palette. The theme tokens stay as in v2: neutrals, one blue accent on data, verdict colours on
pills only.

## 3. Sections: Home becomes section lanes

```
┌──────────────────────────────┐
│ Reelbrain              (av)  │  glass top bar on scroll
│ ┌──────────────────────────┐ │
│ │ ▢ Saving: "Watching..."  │ │  only while something processes or needs a look
│ └──────────────────────────┘ │
│ Fact Check  3          See all│
│ [▮▮▮][▮▮▮][▮▮▮] →             │  horizontal, snapping cards, 3:4 reel frame
│ Recipes  5             See all│
│ [▮▮▮][▮▮▮][▮▮▮] →             │
│ Dev and Tools  2       See all│
│ Places  4 · on the map        │
│ Workouts  1                   │
│                               │
│   ( Home  Search  Map  Inbox )│  the liquid pill
└──────────────────────────────┘
```

- **Lanes:** one lane per section that has saves, ordered by most recent activity. Empty
  sections are hidden. A **Sections / Latest** switch at the top keeps the chronological feed.
- **Card faces show each section's own data:** Fact Check shows the verdict pill and the claim
  count; Recipes the time and servings; Tools the stars or "Link checked"; Places the area;
  Workouts the total time. The moment strip runs along the bottom of every card.
- **See all** opens the section screen you already have (filters, statuses, Grocery list, Make
  routine), restyled.
- **Settings** moves to the avatar in the top bar.

## 4. Motion: springs, and every animation answers an action

- **Springs instead of fixed durations:** content uses a critically damped spring (no bounce,
  settles in about 350 ms); the pill and sheets get a small overshoot (damping 0.8).
- **Shared element:** a card's frame grows into the save's header when opened, and shrinks back on
  Back (Flutter `Hero` with a spring curve).
- **Press:** cards and buttons scale to 0.97 under the finger and spring back.
- **Arrival:** a new save comes out of the pill and slides into its lane, the one moment that
  shows the save landed.
- **Sheets:** follow the finger and settle on a spring; flicking past halfway closes them.
- **Kept from v2:** no load choreography, no shimmer, no animation that isn't answering something.
  Skeletons are still flat bars at their real size.
- **Reduced motion:** springs become 150 ms crossfades, nothing scales, and the arrival is a
  fade.

## 5. Shape and type

- **Radii:** cards 24, nested panels 16, controls and glass chrome fully round (up from 20/12, so
  corners nest evenly inside 8 px glass padding).
- **Type:** IBM Plex Sans and Plex Sans Arabic, unchanged. Lane titles are 20/600, card titles
  16/600.
- **Icons:** Material outlined, as you approved.

## 6. Changes to v2

| v2 said | v3 says | Why |
| --- | --- | --- |
| No frosted glass | Glass on floating chrome only | You asked for liquid; glass stays off text |
| Opaque nav bar, 4 destinations | Floating glass pill that changes shape | The signature |
| Motion 150–250 ms, state changes only | Springs (~350 ms settle), still only in answer to actions | "Very fluid" |
| One chronological feed | Section lanes, plus Latest | You asked for sections |
| Destinations Feed, Shelves, Map, Ask | Home, Search, Map, Inbox (Ask comes when it's built) | Destinations that exist today |
| Radii 20 / 12 | 24 / 16 | Glass nesting |

## 7. Build order (each step committed and checked on the phone)

1. Glass material, spring tokens, radii; the gallery shows glass on photos in both themes.
2. The liquid pill: navigation, processing, ready flash; Android share pill with blur.
3. Home as section lanes with section-specific card faces; Sections / Latest switch.
4. Shared-element open and close, press springs, the arrival animation.
5. Glass sheets, map carousel, cooking and workout controls in the pill.
