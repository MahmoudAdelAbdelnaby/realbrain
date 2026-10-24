# Reelbrain brand: Darkroom

Approved 25 Oct. Board: https://claude.ai/artifact/Rw3YpATFBg8UpqTpT6rfJ6 (private). Adds to
design v3 (`DESIGN_V3_PROPOSAL.md`); where they differ on colour or motion, this file wins.

**Idea.** Reels come in raw; Reelbrain develops them. A brain that feeds on reels and glows back
what it learned, under a darkroom's red safelight.

## Mark and icon: Glow

A pale brain (six overlapping lobes, three folds) on a safelight-red radial glow, with seven rays
shining out of it. One drawing everywhere:

| Place | Form |
| --- | --- |
| Launcher (Android 8+) | Adaptive icon: glow background layer, brain + rays foreground; monochrome brain + rays for themed icons |
| Splash (Android 12+) | The same icon, animated once: rays draw outward, the brain swells in (800 ms) |
| In the app | `BrainMark` (painted, no image): app bar logo, processing states, empty states. Animated while something is working: the rays breathe |

## Colour

| Token | Dark | Light | Use |
| --- | --- | --- | --- |
| ground (Ink) | #0D1214 | #F1F4F3 | Behind everything; the liquid moves over it |
| surface (Fixer) | #162024 | #FFFFFF | Cards, sheets |
| raised | #1F2B30 | #E7EDEB | Inputs, nested panels |
| line | #2A383D | #D7DFDC | 1 px edges |
| brand (Safelight) | #FF4F3A | #D2321F | Wordmark, primary buttons, the pill while processing, selection |
| amber | #FFB547 | #A86A00 | Second brand colour: highlights, the liquid |

Text, muted and faint stay as in v2 (all ≥ 4.5:1 on the new grounds). Verdict colours stay.

**Sections get a hue each** (lane dot, moment ticks, status chips; dark / light):
Fact Check #FF6B8A / #C2264B · Dev and Tools #3FD0C9 / #0D7A74 · Recipes #FFB547 / #A86A00 ·
Places #6FA8FF / #2860C4 · Workouts #B6E35A / #4D7A0E. This replaces v2's "sections have no colours".

## Type

Readex Pro (OFL, Latin + Arabic) for the wordmark, lane titles and headings. IBM Plex Sans and
Plex Sans Arabic stay for everything you read.

## Motion

- **Liquid background:** three blurred blobs (safelight, amber, fixer teal) drift slowly under the
  ink on the main screens. They lag behind scrolling, stretch with its speed and spring back; coming
  back to Home rolls a wave across them. A save processing warms them toward red. One GPU shader;
  it stops after a few seconds without touch and stays still with Remove animations on.
- **Predictive back:** the screen shrinks and follows your finger on Android's back swipe.
- **Develop:** a card that just arrived comes up from a red-lit negative to full colour.
- **The mark breathes** wherever something is processing.
