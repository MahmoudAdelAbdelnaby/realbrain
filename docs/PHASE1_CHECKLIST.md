# Phase 1: what was built overnight, and what to check (24 Oct)

Everything below is committed and has passing tests (backend 54, app 37+, Firestore rules 8).
**None of it has been tried on your phone yet**, except P1-07. Your phone had dropped off wireless
debugging, so the newest build isn't installed. I didn't share test reels at night either, to avoid
notifications.

## Start of the day

1. The backend is running in the **backend 8002** terminal tab with tonight's code (Cloudflare
   tunnel; the app follows its address). If that tab is gone, start it again:
   ```powershell
   cd "C:\Users\Sarah Tarek\Documents\ReelBrain\backend"
   ```
   ```powershell
   .venv\Scripts\python -m scripts.serve
   ```
2. Reconnect the phone (Wireless debugging → `adb connect <ip:port>`), then install:
   ```powershell
   & 'C:\Android\Sdk\platform-tools\adb.exe' install -r "C:\Users\Sarah Tarek\Documents\ReelBrain\app\build\app\outputs\flutter-apk\app-debug.apk"
   ```
   Or just tell me "phone connected" and I'll install it.

## Phone checks, one per ticket

| Ticket | Try this | Expect |
| --- | --- | --- |
| P1-01/02 Design | Long-press **Reelbrain** in the feed | Design gallery: every colour with its contrast, the type scale in Plex Sans and Plex Arabic, radii, chips, pills, cards, empty state, bottom sheet. The sun/moon and RTL buttons flip theme and direction. The rest of the app now uses the same tokens (cards with a 1 px edge, round buttons). Sharing a reel now shows a round ✓ **Saving to Me** pill for 1 s over TikTok instead of the plain toast. |
| P1-08 Fact Check | Share a reel making health or money claims | Notification starting with the verdict ("Mostly false: …"). The save shows "AI-generated · checked <date>", a verdict pill per claim, a correction, sources. **Dive deeper** writes an explainer in a few seconds. |
| P1-09 Tools | Tap **Dev and Tools** in the feed's counter row | Each tool shows ★ stars and last update (GitHub) or "Link checked". **Copy** copies the snippet. Status chips To try / Tried / Using / Not useful stick. Category filter works. |
| P1-10 Recipes | Share a recipe reel, open it | **Serves − / +** rescales amounts; "≈" marks guesses; tags. In **Recipes**, tick two recipes → **Grocery list** merges the same ingredients; Share works. |
| P1-11 Cooking mode | **Cook** on a recipe | Light screen, big text, swipe between steps, the reel's frame at that step. Start a timer, swipe on: it stays pinned and counts; it vibrates and beeps at zero. The screen never sleeps. |
| P1-12 Places | Open a places save (the Aroya cruise one) | **Open in Maps** opens Google Maps searching that place. Visited chip in **Places**. **Places → map icon:** pins on OpenStreetMap, cards along the bottom follow the pins. Share a new places reel to see a pin (older saves have none until re-filed under Places). |
| P1-13 Workouts | Share a workout reel | Each exercise has a round frame from the reel. In **Workouts**, tick saves → **Make routine** → edit seconds (± 5) → **Start routine**. |
| P1-14 Workout mode | **Start workout** | Ring timer around the pose, big digits, 3-2-1 clicks and vibration, rest then next by itself, pause/skip, Done for reps, "Workout complete". |
| P1-15 Library | 🔍 in the feed | Search an Arabic word (e.g. كروز) and an English one. Platform and section filters narrow the list. |
| P1-16 Settings | ⋮ → Settings | Switch to العربية and Dark: the whole app flips to right-to-left and dark. Saves today (no cap); Gemini use per model today. |
| P1-17 Regression | Nothing on the phone | Tonight: 5/7 → 7/7 on the 7 seed reels after a scoring fix and a tighter Fact Check prompt (details under P1-17). Add your own reels to `test/fixtures/reels.md` (target 20) and run `.venv\Scripts\python -m scripts.regression` in `backend`. |

When a check passes, tell me and I'll tick the ticket.

## Decisions (answered 25 Oct)

All approved, except the daily cap, which is removed. Recorded in `BUILD_PLAN.md`.

1. **Map:** OpenStreetMap + Nominatim now (merged); Google Places/Maps when Blaze is on.
2. **Search** uses a stored `search_text` per save, searched on the phone; transcripts are stored.
3. **Fact Check grounding** uses Gemini 2.5 Flash-Lite; "Dive deeper" once per save.
4. **Tool status** is per save, with `using` and `not_useful` added.
5. **Recipes** have AI `tags`.
6. **Lists:** members may change `item_refs` and `overrides` only.
7. **Gemini keys** stay in `backend\.env` until Secret Manager (billing).
8. **No daily cap.** Saves are still counted and shown in Settings.
9. **Icons** are Material outlined, not Phosphor.

## Known issues

- **Flash-Lite files more loosely than Flash.** When both Flash models are busy, Flash-Lite took
  the AirPods ad for Fact Check. The regression run is where to watch this.
- **3.8 Flash is often overloaded (503).** The chain handles it, but busy hours mean slower saves.
- **Your name isn't on your user record.** Firebase's provider sign-in doesn't hand it over. It
  only matters for "Added by" in Phase 2.
- **Dive deeper runs after the reply on the same server.** That's fine on your PC; on Cloud Run
  it should move onto the task queue.
- **Your wife's phone is an iPhone,** so household testing waits for Phase 2.
