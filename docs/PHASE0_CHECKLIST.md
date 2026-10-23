# Phase 0: what to test when you're home

P0-01 and P0-02 are ticked. P0-03 to P0-07 are built and committed, with unit tests passing, but **not ticked**: each needs a real run on your phone or in your Google Cloud project. Work top to bottom. Open a new terminal first so it has `PUB_CACHE`.

## 0. Reconnect the phone

```powershell
& 'C:\Android\Sdk\platform-tools\adb.exe' connect 192.168.1.9:<port from Wireless debugging>
```
```powershell
cd "C:\Users\Sarah Tarek\Documents\ReelBrain\app"
```
```powershell
$env:TEMP = "C:\Temp"; $env:TMP = "C:\Temp"; flutter run
```

The app now opens on a **Saves** screen: every share with its status, size, duration and download time, or an error code.

## 1. P0-03 on-device downloader (phone only, no backend needed)

- [ ] Share 10 test reels (5 TikTok, 5 Instagram) to Reelbrain · Me or Home, then **close the share sheet right away**. Each row should go `queued → downloading → downloaded` with a size and duration. That shows the background worker survives the share sheet closing.
- [ ] Do half on home Wi-Fi and half on mobile data.
- [ ] Target: at least 9 of 10 downloaded. Failures show a code: `NO_NETWORK`, `TIMEOUT`, `LOGIN_REQUIRED`, `NOT_FOUND`, `UNSUPPORTED_URL`, `BLOCKED`, `NO_OUTPUT`, `INIT_FAILED` or `UNKNOWN`.
- [ ] The first download after install takes longer, because the app unpacks Python and updates yt-dlp once a day.
- Log while testing: `& 'C:\Android\Sdk\platform-tools\adb.exe' logcat -s Reelbrain`

## 2. P0-04 backend pipeline, locally (needs your Gemini key)

- [ ] Copy `backend\.env.example` to `backend\.env` and put your key after `GEMINI_API_KEY=`.
- [ ] Copy one downloaded reel off the phone (debug builds allow this):
  ```powershell
  & 'C:\Android\Sdk\platform-tools\adb.exe' shell run-as com.reelbrain.reelbrain ls files/reels
  ```
  ```powershell
  cmd /c "C:\Android\Sdk\platform-tools\adb.exe exec-out run-as com.reelbrain.reelbrain cat files/reels/<name>.mp4 > C:\Temp\reel1.mp4"
  ```
- [ ] Run it through Gemini. This prints the JSON, latency and detected sections, and cuts the key frame next to the file:
  ```powershell
  cd "C:\Users\Sarah Tarek\Documents\ReelBrain\backend"
  ```
  ```powershell
  .venv\Scripts\python -m scripts.extract_file C:\Temp\reel1.mp4 --platform tiktok
  ```
- [ ] YouTube needs no download: `.venv\Scripts\python -m scripts.extract_file --url https://youtube.com/shorts/...`
- [ ] Target: valid JSON for all 10 reels. If Gemini rejects the schema or the model name, send me the error. That's the one part I couldn't run without your key.

## 3. P0-05 Cloud Run + Cloud Tasks (your Google Cloud, so you run it)

In the Firebase console for `reelbrain-dev`:
- [ ] **Authentication → Sign-in method → Anonymous: enable.** This is for the spike only, see "Needs your OK" below.
- [ ] **Project settings → Add app → Android**, package `com.reelbrain.reelbrain`. Note the **App ID** (`1:...:android:...`) and the **Web API key**. You don't need to download `google-services.json`.
- [ ] Firestore and Storage are created (setup checklist).

Then in a new terminal:
```powershell
gcloud auth login
```
```powershell
cd "C:\Users\Sarah Tarek\Documents\ReelBrain"
```
```powershell
.\infra\deploy.ps1
```
It asks for the Gemini key once, which goes to Secret Manager, then prints the API URL and four lines to add to `app\android\local.properties`:
```
reelbrain.apiUrl=https://reelbrain-api-....run.app
reelbrain.firebaseProjectId=reelbrain-dev
reelbrain.firebaseApiKey=...
reelbrain.firebaseAppId=1:...:android:...
```
- [ ] Rebuild and run (step 0), then share one reel. Its row should end on `uploaded` with a save id.
- [ ] In the Firestore console, find `spaces/me/saves/<save id>`. Its status should go to `ready`, with `items` underneath and a `key_frame_url`.
- [ ] Gemini 429s are retried by the queue (3 attempts, backoff from 10 s to 5 min), not failed.

## 4. P0-06 fallback chain

- [ ] Share a private or login-only Instagram reel, or turn the phone's download off by sharing while yt-dlp is failing. The phone row shows `sent_without_video`. In Firestore the save gets `fetch_path` (`youtube`, `mirror`, `yt-dlp` or `caption`) and `fetch_steps` with each step's result. Caption-only ends as `partial`, still with a summary.

## 5. P0-07 spike report

```powershell
gcloud auth application-default login
```
```powershell
cd "C:\Users\Sarah Tarek\Documents\ReelBrain\backend"
```
```powershell
.venv\Scripts\python -m scripts.spike_report --cloud
```
- [ ] Paste the table into `docs/BUILD_PLAN.md` under P0-07, mark **Correct?** for each reel, and record the decisions: on-device download confirmed or replaced, the Gemini model to pin, and the real free quota from AI Studio.
- [ ] Phase 0 gate: 10 real reels (5 TikTok, 5 Instagram) from share to correct JSON, at $0. Check the billing page shows $0.

## 6. GitHub

- [ ] Create the private `reelbrain` repo, then `git remote add origin ...` and `git push -u origin main`. CI runs lint, tests, the APK build and the Kotlin tests.
- Deploy-on-push to Cloud Run (in the tech spec) needs Workload Identity Federation set up. I'll do that with you after the first manual deploy works.

## Needs your OK (spec additions I made so Phase 0 could run end to end)

1. **Phase 0 auth is Firebase anonymous sign-in on the phone.** P1-03 links it to Google sign-in and keeps the same uid.
2. **`POST /v1/saves` takes optional `caption` and `creator`.** The phone has them from yt-dlp or the share text, and the save doc already has those fields.
3. **Extra save-doc fields for the spike:** `fetch_path`, `fetch_steps`, `extract_ms`, `no_video_reason`.
4. **The transcript isn't stored in Firestore yet.** The contract lists no field for it, but P1-15 search needs it. Decide by P1-15: a `transcript` field on the save, or a subcollection.
5. **`/section` and `/deep-dive` are left for their own tickets** (P1-07, P1-08).
6. **The default model is `gemini-flash-latest`** until P0-07 pins one.

Say yes or no to each and I'll update the Locked spec in `BUILD_PLAN.md` to match.
