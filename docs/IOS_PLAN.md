# I1: Realbrain on iPhone without the $99 (approved 26 Oct: the web app)

Goal: your wife gets an app-like Realbrain on her iPhone from a **link**, with no Apple Developer
account and no Mac, so she can test it. The App Store decision comes later.

## 1. Recommendation: the real app as a web app ("Add to Home Screen")

- We build the same Flutter app for the web (`flutter build web`) and host it on **Firebase Hosting**
  (free on Spark) at a new site, e.g. `https://reelbrain-app.web.app`.
- She opens the link in Safari and taps **Share, then Add to Home Screen**.
- After that, it opens from her home screen **full-screen, with its own icon and splash**, and no
  Safari bars. It feels like an app.

It's the real app, not a mockup:
- She signs in with Google and sees the real feed, Recall, Threads and Spaces from Firestore.
- She saves real reels through the backend on the Oracle VM.
- A clickable mockup with fake data would take the same effort and test less.

| | Web app (recommended) | Sideloadly + free Apple ID (fallback) |
|---|---|---|
| Cost | $0 | $0 |
| How she gets it | A link | You plug her iPhone into your PC by USB |
| Expiry | Never. Each update reaches her the next time she opens it. | **Every 7 days.** You re-install it by cable. |
| Needs | Nothing | iTunes and iCloud for Windows, Developer Mode on her phone, her Apple ID typed into Sideloadly, and a cloud Mac build (Codemagic) |
| Share sheet | No. She pastes the link in Create (an iOS Shortcut can help, see section 4). | No. A free account can't do share extensions. |
| Push | Possible later. iOS 16.4+ supports web push for home-screen apps (I3). | No |
| 3D workout figure | Needs a small web version (an iframe) | Works as it is |

- **The iPad:** it can't build an iPhone app for us (Flutter needs a Mac), but it's a good second
  test device for the web app.
- **If you later pay the $99:** this work isn't lost. The backend, CORS and the web build stay, and
  the native iOS route (Codemagic plus TestFlight, plus a share extension) becomes its own ticket.

## 2. What changes in the code

The app's native work all goes through one method channel (`app/lib/core/native.dart`). On the web
that channel doesn't exist, so I add a small **web implementation of the same calls in Dart**.
Android keeps using Kotlin unchanged.

| Native call (Android) | On the web |
|---|---|
| `api` (HTTP as the Firebase user) | `fetch` with the Firebase ID token |
| `enqueue` (download on the phone, upload, queue) | Sends the link only: `POST /v1/saves`, then `/no-video`. The backend then fetches the video itself: YouTube, the TikTok mirror, yt-dlp on the VM, then the caption. That chain already exists. |
| `saves`, `retryWaiting` | A small local list (`localStorage`) and a resend on open |
| `fid` | `null` (no push in I1) |
| `openUrl`, `share` | `window.open`, `navigator.share` (the iOS share sheet) |
| `initialLink` | `null`: an invite link opens the existing join page, which shows the code to type in Spaces. |
| `setBackendUrl` | Kept in memory, from Firestore `config/backend` as today |

Other pieces:
- **Sign-in:** on the web, `signInWithProvider` becomes `signInWithRedirect` (popups are unreliable
  in home-screen apps). The auth domain is the Hosting site itself, which avoids Safari's
  cross-site storage blocking.
- **Firebase config:** read from Hosting's own `/__/firebase/init.json` at startup, so no Firebase
  key is added to the repo.
- **Backend CORS:** add `CORSMiddleware` allowing only the app's origin, in `backend/app/main.py`.
  F1 has uncommitted edits in that file, so **I coordinate with F1** (or F1 adds the 3 lines), then
  deploy with `infra/oracle/deploy.cmd`.
- **Web shell:** `app/web/` (new, from `flutter create --platforms web`), with:
  - `manifest.json`: name, theme colour, `display: standalone`.
  - The `apple-touch-icon`, made from the Android launcher icon.
  - The iOS status-bar meta tags.
  - The brand background while the app loads.
- **Hosting:** a second site on the same Firebase project. `firebase.json` gets a second hosting
  target. The landing page and the `join` page stay where they are, and I coordinate with the
  landing session before touching `firebase.json`.
- **3D figure (F1):** `webview_flutter` doesn't run on the web. After F1 lands, the web build shows
  the same `assets/figure/index.html` in an iframe. Until then, the web build shows a "View on
  Android" placeholder.
- **`pubspec.yaml`:** possibly one dependency, `web` (the official package for `fetch`,
  `localStorage` and `navigator.share`). I coordinate with the main session before adding it.

## 3. What you do yourself

- Run `firebase hosting:sites:create reelbrain-app`, or let me run it with your signed-in CLI.
  It's free and creates no billing.
- Add the new domain in Firebase console → Authentication → Settings → Authorized domains. I give
  you the exact name.
- Send her the link. She does Add to Home Screen once and signs in with her own Google account.

## 4. Day one vs later

**Day one (I1):**
- She installs from the link and gets the home-screen icon.
- She signs in with Google.
- She saves a reel by pasting its link in Create.
- She watches it process in the feed.
- She can use Recall, Threads and Spaces.
- She can join your shared space by typing the code from an invite link.

**Later:**
- **I2:** a "Save to Realbrain" **iOS Shortcut** in her share sheet. It opens
  `reelbrain-app.web.app/save?url=…`, so saving from TikTok or Instagram becomes a single tap.
  Caveat: iOS opens it in Safari, which has its own sign-in, so she signs in there once too.
- **I3:** web push for "save ready" (FCM web plus the VAPID key, iOS 16.4+).
- The 3D figure iframe, once F1 is committed.
- Native iOS via TestFlight, if and when you pay the $99.

**Known gap:** nothing downloads on the iPhone, so the backend does it. That worked for Instagram and
TikTok in the test (section 6), but the VM's IP could get blocked later.

## 5. Done for I1

- She opens Realbrain from her home screen, signs in, and one real pasted reel comes back processed.
- Android still works: `flutter analyze` is clean, `flutter test` passes, and the Android build is
  unchanged.
- Committed as `I1: ...` with only the `app/web/`, the web Dart files, `firebase.json`, the CORS
  lines and `docs/` files. F1's files aren't included.

## 6. Server-side download test (26 Oct, on the VM, `fetch.py` run against real saved links)

| Link | Result |
|---|---|
| Instagram, 3 reels | **All downloaded with yt-dlp on the VM**, 4 to 20 MB in about 2 s each |
| TikTok `ZSgm3sUEk` | Downloaded through the mirror (3 s) and also with yt-dlp (3 s) |
| TikTok `ZSgm7onTd` | Failed both ways: "Video not available" (10240). The video is most likely deleted or private. |
| YouTube | Not downloaded. Gemini reads the URL itself, which is the existing path. |

So the backend can do the download itself. The web app relies on that, and the same idea could
later drop the download-then-upload step on Android too (a separate ticket). Two caveats:
- yt-dlp warns that TikTok "impersonation" isn't installed (the `curl_cffi` package). Adding it
  would make TikTok more robust.
- Datacenter IPs can be blocked at any time, so watch the `fetch_path` field on new saves.
