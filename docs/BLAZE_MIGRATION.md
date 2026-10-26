# B1 · Backend off the PC, onto Google Cloud (Blaze)

Status: **not chosen** (26 Oct 2026). Oracle Cloud Always Free was picked instead: see `docs/ORACLE_MIGRATION.md`. Kept for reference if the project moves to Blaze later.
Finishes P0-05 in `docs/BUILD_PLAN.md`; that ticket's text is updated when B1 lands.

## What runs where

| Piece | Today (PC) | After B1 |
|---|---|---|
| API + processing | `scripts.serve` on port 8002, Cloudflare quick tunnel | Cloud Run service `reelbrain-api` from `backend/Dockerfile` |
| Processing hand-off | thread in the API process (`tasks._run_local`) | Cloud Tasks queue `process` → `/internal/process` (already coded: `TASKS_QUEUE`, OIDC checked by `auth.cloud_tasks`) |
| Videos (transient) and key frames | `backend/data/videos`, `backend/data/frames` | Cloud Storage bucket `reelbrain-dev.firebasestorage.app` (already coded: `GCS_BUCKET`) |
| Documents | Firestore | Firestore, unchanged |
| Gemini key(s) | `backend/.env` | Secret Manager `gemini-api-key` (and `gemini-api-keys` if the key chain is used), mounted as env vars |
| Daily Recall push | `recall.loop` thread in `serve.py` | Cloud Scheduler, 19:00 Africa/Cairo daily → `POST /internal/recall` |
| Backend address | tunnel URL written to Firestore `config/backend` on each start | fixed `https://reelbrain-api-<hash>.europe-west1.run.app`, written to `config/backend` once at deploy |

**Region: `europe-west1` (Belgium)** for Cloud Run, the queue, the scheduler job and the bucket, next to Firestore
(the deploy checks Firestore's actual location first and uses that region if it differs). Closest
cheap region to Egypt; latency barely matters since processing is async.

Cloud Run settings: 1 vCPU, 1 GiB (2 GiB if MediaPipe from F1 needs it), timeout 600 s,
min instances 0, **max instances 2** (that is the real spending cap; the budget only emails).
Queue: 3 attempts, 10 s → 300 s backoff, 1 at a time, one save per 15 s (free Gemini rate), as in `infra/deploy.ps1`.

## Code changes (small)

1. **Dockerfile**: `python:3.11-slim` (matches the dev venv and F1's MediaPipe), and
   `apt-get install ffmpeg libgl1 libglib2.0-0` so MediaPipe's OpenCV imports. Requirements are
   installed from whatever `requirements.txt` holds when we deploy, so F1's new line rides along.
2. **Key frames**: in the cloud `store.put_frame` writes `gs://…`, which the phone can't show.
   Instead it keeps the same relative path as today (`/dev/frames/<space>/<save>.jpg`) and on
   Cloud Run that route answers with a 302 to a 1-hour signed Storage URL. The app needs no change,
   and saves made on the PC keep working once their frames are copied to the bucket (one `gcloud storage cp`).
3. **Dive deeper** (`/v1/saves/{id}/deep-dive`) runs in a FastAPI background task. Cloud Run takes
   the CPU away once the response is sent, so it would stall. It goes through Cloud Tasks too
   (`/internal/deep-dive`, same queue); locally it stays a thread.
4. **Recall**: `POST /internal/recall` calls `recall.run_once()`, guarded like `/internal/process`
   (OIDC token from our service account). Cloud Run gets `TZ=Africa/Cairo` so "today" and the
   19:00 rule mean your evening. The `recall.loop` thread stays in `serve.py` for PC runs.
5. **`infra/deploy.ps1` → `infra/deploy.sh`** (Git Bash, calls `gcloud`/`firebase.cmd`; your
   execution policy blocks .ps1). Same steps as today plus the scheduler job, the bucket's
   7-day auto-delete rule on `videos/`, and writing the Cloud Run URL to `config/backend`.
   Gemini key goes from `backend/.env` to Secret Manager through a pipe, never printed or written to disk.

## How the app finds the backend

No app change. The app already follows Firestore `config/backend`; the deploy writes the Cloud Run
URL there once and every phone switches by itself. Also set `reelbrain.apiUrl` in
`app/android/local.properties` to that URL so a fresh install starts on it before Firestore answers.

## Keeping the PC path for development

`scripts.serve` keeps working exactly as now, with videos in `backend/data`. One change: it no
longer overwrites `config/backend` by default (that would pull your phone off Cloud Run).
`--take-over` publishes the tunnel address as today and puts the Cloud Run URL back when you stop it
(Ctrl+C). Without the flag, the PC backend is for tests and `AUTH_MODE=dev` curl runs.

## Cost at your usage

Assumed: 2 people, ~20 saves a day (~600 a month), ~90 s of processing each.

| Item | Use per month | Free allowance | Cost |
|---|---|---|---|
| Cloud Run | ~55k vCPU-s, ~55k GiB-s | 180k vCPU-s, 360k GiB-s | $0 |
| Cloud Tasks | ~1.5k operations | 1M | $0 |
| Cloud Scheduler | 1 job | 3 jobs | $0 |
| Secret Manager | 1–2 secrets, a few hundred reads | 6 versions, 10k reads | $0 |
| Cloud Storage | ~60 MB frames, videos deleted after processing | 5 GB only in US regions | ~$0.01 |
| Storage egress (frames to phones) | ~0.5 GB | 1 GB from Cloud Run, not from Storage | ~$0.06 |
| Artifact Registry | image ~1.5 GB with MediaPipe | 0.5 GB | ~$0.10 |
| Cloud Build | ~5 deploys × 5 min | 2,500 min | $0 |
| Firestore | as today | unchanged | $0 |
| **Total** | | | **about $0.20 a month** |

**Budget alert:** $5 a month on the billing account, emails at 50 %, 90 % and 100 %.
(BUILD_PLAN said $1; with Artifact Registry alone near $0.10 a $1 alert is fine too, your pick.)

### ⚠ Gemini can become paid when billing is on

The setup checklist created the Gemini key **in `reelbrain-dev`**. Once that project has billing
(Blaze), AI Studio puts its keys on the **paid tier**: no more free quota, every call billed.
At ~600 saves a month on Flash with video that is roughly **$3–8 a month**, more if the key chain
adds keys. To stay free: in AI Studio, create the key in a separate project **without billing** on
the same Google account (one project per account, so this is not quota stacking), and put that key
in Secret Manager. Check AI Studio → API keys for which project the current key belongs to and
whether it says "Free" or "Paid" after you enable Blaze.

## Steps only you can do

1. Enable Blaze on `reelbrain-dev` with your card (Firebase console → Usage and billing).
2. Create the budget alert (Cloud console → Billing → Budgets & alerts), amount from above.
3. Log `gcloud` in with the Google account that owns `reelbrain-dev`. Right now it is logged in as
   a different (work) account on project `zinc-fold-501609-g2`; run, in your own terminal:
   `gcloud auth login` then `gcloud config set project reelbrain-dev`.
   Also `gcloud auth application-default login` if the PC backend should keep using your account.
4. Firebase console → Storage → Get started, location `europe-west1` (Spark could not create it).
5. Approve the API enablement when the deploy asks (Run, Cloud Tasks, Scheduler, Secret Manager,
   Artifact Registry, Cloud Build, IAM Credentials).
6. Decide the Gemini question above; if you make a new free key, paste it into `backend/.env`
   as `GEMINI_API_KEY` and I move it to Secret Manager from there.

## After approval, in order

1. Code changes 1–5 above, backend tests (`.venv\Scripts\python -m pytest`), ruff clean.
2. `bash infra/deploy.sh`: APIs, service account and roles, secrets, queue, bucket rule, Cloud Run,
   scheduler, `config/backend`.
3. `/health` on the Cloud Run URL; copy old frames to the bucket.
4. One real save from the S22 (wireless adb) through Cloud Run to Firestore, frame visible, plus one
   manual run of the Recall job.
5. Update P0-05 in `BUILD_PLAN.md`, commit `B1: …`.

Not in B1: GitHub Actions deploy on push (BUILD_PLAN's CI row), a custom domain, Places/Maps on Blaze.
