# W1 · A landing page for Realbrain, served from the Oracle VM

Status: **approved 26 Oct** (root, mailto join button). Deployed with `infra/oracle/deploy-web.sh`.

## Where it lives

- **Address:** the root of the backend's address, `https://realbrain-mahmoud.duckdns.org/`.
  Today `/` returns the API's `404 {"detail":"Not Found"}`; no app route uses it.
- **Routes:** Caddy answers exactly two things from disk and proxies everything else to the API as it
  does now, so a new API route can never be shadowed by the page:

  | Path | Served by |
  |---|---|
  | `/` (and `/index.html`) | the page, from `/srv/reelbrain/web` |
  | `/site/*` | the page's files: videos, fonts, icon |
  | everything else (`/health`, `/v1/*`, `/internal/*`, `/dev/*`, …) | `reverse_proxy 127.0.0.1:8000`, unchanged |

- **Source:** `web/landing/` (one `index.html`, a `site/` folder, ~4 MB: the two video cuts 3.2 MB, fonts). No build step, no framework, no
  CDN: fonts are the app's own Inter files, the mark is drawn from the same
  points as `BrainMesh` (`app/lib/core/brain_mark.dart`, `app/tool/brain_mesh.py`), colours are the
  tokens in `app/lib/core/theme/tokens.dart` (dark and light).
- **No 3D figure:** "Follow the motion" was dropped from the page (your call, 26 Oct).

## Deploy (repeatable)

`infra\oracle\deploy-web.cmd` (or `sh infra/oracle/deploy-web.sh`): ships `web/landing` and the
`Caddyfile` from the **last commit** (`git archive HEAD`, like `deploy.sh`) to the VM, swaps
`/srv/reelbrain/web` (keeping `web.old` for rollback), validates and installs the Caddyfile and reloads Caddy. It doesn't rebuild or restart
the backend container. Checks after: `curl /` is the page, `curl /health` is still the API.
Documented in `docs/ORACLE_SETUP.md` next to the backend deploy.

## What the page says

_Revised 26 Oct after your review: the video is the hero, the process is told as a scroll story,
light theme first with a dark toggle, sections come to life on scroll and are examples (more coming).
Arabic is off for now._

English only. Light by default (the app's light tokens), a moon/sun button switches to the dark
tokens and is remembered. Mobile first.

1. **Hero = the launch video, full screen**, edge to edge behind the header (a 9:16 cut on phones,
   16:9 elsewhere), muted with Sound on / Pause. No text over the film (your call, 26 Oct):
   the slogan "Your saved reels, given a Realbrain." is its closing line. Only Join the test,
   Sound on and Pause sit at its bottom edge. Scrolling slides the page up
   over the film, which dims and pauses once covered, and plays again when you scroll back.
2. **The story: five steps, one short scroll each** (the page snaps to each step). Scrolling only
   picks the step; the phone then plays that step's animation by itself, so stopping anywhere shows a
   finished state. Big words pop in, the phone bumps, the background greys for the graveyard and
   lights up violet when Realbrain steps in.
   1. *You find a good one.* A recipe, read out at double speed. (The feed scrolls to a koshari reel.)
   2. *You save it.* Feels like keeping it.
   3. *You never see it again.* Saved is where reels go to die. The pitch, so it runs slower (~4 s):
      the words land one by one, the reel sinks into the Saved grid, everything greys, then the line.
   4. *Realbrain digs it out.* Every amount. Every step. Every timer.
   5. *Now you cook it.* And if you forget, it comes back. (Cook now, and the "Remember this?" push.)
3. **What comes out of a reel:** the six sections as examples, each showing the raw input (a
   mumbled line, a half-read sign) and, as it scrolls into view, what Realbrain extracts and its
   action (Cook now, Start, Go, Try now, Read, Explore). "More sections are on the way."
4. **Recall:** a working card (Cook now / Not now / Archive, each says what happened).
5. **Brain Threads:** tap an interest to see its tags and why it connects to another.
6. **Join the test:** "Android, free, a small group." Button opens an email to you.
7. Footer: "Made in Cairo. No cookies or trackers on this page."

## Launch video

Done with `brag-slim`: 22 s, 1080p, with a soundtrack: `web/landing/site/realbrain-launch.mp4`
(1.7 MB, poster `brag.jpg`), plus a 9:16 cut for phones, `realbrain-launch-vertical.mp4`. Share copy in `docs/LAUNCH_COPY.md`. Example content in it and on the
page (Koshari, bar dips, a Zamalek café, the 10 % brain myth) is illustrative, not real saves.

## Questions for you

1. **Join the test target:** a `mailto:` to `mahmoud.ad9292@gmail.com` (public on the page, so it
   will get some spam), or a Google Form / WhatsApp link you give me? Default: the mailto.
2. Root `/` as above, or a path like `/about`? Default: root.

Not in W1: analytics, a sign-up database, a custom domain, an iPhone pitch.
