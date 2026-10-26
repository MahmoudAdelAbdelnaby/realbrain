# B1 · Backend off the PC, onto an Oracle Cloud Always Free VM

Status: **proposal, waiting for approval.** Nothing is created or deployed until you say go.
Replaces `docs/BLAZE_MIGRATION.md` (not chosen). Firebase stays on **Spark**: Firestore, Auth and
push keep working as they do today.

## What runs where

| Piece | Today (PC) | After B1 |
|---|---|---|
| API + processing | `scripts.serve` on port 8002 + Cloudflare quick tunnel | same code in Docker on an Ampere A1 VM (Ubuntu 24.04 ARM) |
| Processing hand-off | thread in the API process | unchanged (no Cloud Tasks) |
| Videos (transient) and key frames | `backend/data/` | `/srv/reelbrain/data` on the VM's block volume, mounted into the container |
| Documents | Firestore through your gcloud login (ADC) | Firestore through a Firebase service-account key on the VM |
| Gemini key(s) | `backend/.env` | `/etc/reelbrain/env`, root-only (`chmod 600`), never in git |
| Daily Recall push | `recall.loop` thread in `serve.py` | unchanged, same thread, `TZ=Africa/Cairo` |
| HTTPS address | random `*.trycloudflare.com`, re-published to `config/backend` each start | fixed `https://<name>.duckdns.org` through Caddy, published to `config/backend` on start |
| Restart on reboot | none | Docker `--restart unless-stopped` (Docker itself is a systemd service) + Caddy's systemd unit |

## The VM

- **Shape:** VM.Standard.A1.Flex, start at **2 OCPU / 12 GB** (MediaPipe + ffmpeg + a few saves at once
  fit easily); resize up to 4 / 24 later. If the console says "Out of capacity", try 1 OCPU / 6 GB,
  another availability domain, or retry later; once it exists, resizing is usually possible.
- **Fallback:** the x86 E2.1.Micro (1 GB) is too small for MediaPipe. If A1 never comes, B1 runs
  there without the workout figure, or we wait.
- **Region:** your home region, chosen at sign-up and **fixed forever**. Nearest to Egypt:
  Jeddah (`me-jeddah-1`) or Dubai (`me-dubai-1`). Always Free resources exist only in the home region.
- **Disk:** 100 GB boot volume (of the 200 GB free). Videos are deleted after processing; frames are ~100 KB each.
- **Idle reclaim:** Oracle may stop an Always Free VM whose CPU, network and memory all stay under
  ~20 % for 7 days. Our backend idles most of the day, so it is at risk. **Recommended: upgrade the
  account to Pay As You Go** (needs your card, still $0 while you stay on Always Free shapes; it also
  gives better A1 capacity). Add a **$1 budget alert** in OCI Billing so any mistake emails you.
  Burning CPU on purpose to dodge the rule is not in the plan.

## Docker on ARM

- The existing `backend/Dockerfile` with three changes: `python:3.11-slim` (multi-arch, matches the
  dev venv), `apt-get install ffmpeg libgl1 libglib2.0-0` (MediaPipe pulls `opencv-contrib-python`,
  which needs libGL), and `COPY scripts scripts` so the container can run `scripts.serve`.
- **MediaPipe on aarch64: checked.** PyPI has `mediapipe-1.1.1-py3-none-manylinux_2_28_aarch64.whl`;
  slim (Debian 12, glibc 2.36) meets `manylinux_2_28`. Its deps (opencv-contrib-python, numpy,
  matplotlib) have aarch64 wheels too. F1's `requirements.txt` rides along at build time; the first
  build on the VM proves it (`python -c "import mediapipe"` in the container). If its `sounddevice`
  dep complains, add `libportaudio2`.
- Built on the VM itself (`docker build`), so no registry and no cross-compiling.

## HTTPS with a fixed address

**Caddy + a free DuckDNS name** (`reelbrain.duckdns.org` or similar):
Caddy gets a Let's Encrypt certificate by itself and proxies to the container on `127.0.0.1:8000`.
Free, no domain to buy. Chosen over a Cloudflare named tunnel because that needs a domain on
Cloudflare (~$10/year), and Cloudflare's free plan caps request bodies at **100 MB** while the
backend accepts 200 MB videos (`MAX_VIDEO_BYTES`); the quick tunnel today has the same cap.
If you'd rather buy a domain later, Caddy just gets the new name.

**How the app finds it:** no app change. On start the container runs
`python -m scripts.serve --lan --publish --port 8000` with `PUBLIC_URL=https://<name>.duckdns.org`,
which writes that fixed URL to `config/backend` (as today, just never changing). Also set
`reelbrain.apiUrl` in `app/android/local.properties` to it for fresh installs.

## Network and firewall

- OCI security list for the subnet: ingress TCP **80 and 443** from 0.0.0.0/0 (80 only for the
  certificate challenge and redirect), **22 from your home IP only**. Nothing else.
- Oracle's Ubuntu images also ship `iptables` rules that reject everything but 22; open 80/443 there
  too (`iptables -I INPUT ... ` + `netfilter-persistent save`), the common "it doesn't connect" trap.
- The container listens on `127.0.0.1:8000` only; Caddy is the one public door.
- SSH by key only (Oracle's default), `unattended-upgrades` on for security patches.
- `AUTH_MODE` is never set on the VM, so `/docs` and dev tokens stay off.

## Firestore without Blaze

A dedicated service account `reelbrain-vm` with only Cloud Datastore User and Firebase Cloud
Messaging API Admin; you create its JSON key in the Cloud console (`docs/ORACLE_SETUP.md` step 8).
_Changed 26 Oct: the Firebase Admin SDK account was deleted by mistake while rotating its key; the
narrower account replaced it._ I copy it to `/etc/reelbrain/sa.json` (root-only, mounted read-only into the
container) and set `GOOGLE_APPLICATION_CREDENTIALS` to it. `firebase_admin` already uses whatever
ADC finds, so no code change; `GOOGLE_CLOUD_QUOTA_PROJECT` is not needed with a service-account key.
Works on Spark: Firestore and FCM don't need billing.

## Code changes (small)

1. Dockerfile, as above.
2. `scripts/serve.py`: publish to `config/backend` only with `--publish`. The VM passes it; your PC
   run doesn't, so starting the backend on the PC for development no longer drags the phone off the
   VM. Add `--publish` on the PC when you really want the phone on it; restarting the VM service moves it back.
3. `infra/oracle/`: `Caddyfile` (3 lines), `reelbrain.env.example` (names only), `setup.sh` (once),
   `update.sh` (`docker build`, replace the container) and `deploy.sh`.
   _Changed during B1 (26 Oct): the repo has no git remote, so the VM can't `git pull`. Updating is
   `infra\oracle\deploy.cmd` from PowerShell (or `sh infra/oracle/deploy.sh` in Git Bash) on the PC: it ships the last commit (`git archive HEAD`)
   over SSH and runs `update.sh`. If the repo gets a GitHub remote later, a pull on the VM works too._
4. Remove `infra/deploy.ps1` (Cloud Run, not chosen). Nothing in `backend/app/pipeline/`.

## A live demo with a few people

**Gemini is the bottleneck, not the VM.** Each save is 1 Extract call, plus 1 grounded call for Fact Checks.
The free tier allows roughly 10 requests a minute and a few hundred a day per key for Flash (check
AI Studio for today's numbers), and the backend already spaces calls 15 s apart (`GEMINI_MIN_GAP_S`).
So **about 4 saves a minute** on one key; 5 people sharing 3 reels each wait up to ~4 minutes for the last one.

- **Key rotation:** `GEMINI_API_KEYS=key1,key2,...` already exists; each key tries every model
  before the next. Each key must come from **its own Google account** (yours, your wife's);
  several projects on one account to stack quota breaks the Gemini terms. With 2–3 keys you can
  lower `GEMINI_MIN_GAP_S` to 8 for the demo.
- **Paid if needed:** turning on billing for one key's project removes the limits (hundreds of
  requests a minute). A 60 s reel on Flash is about 20k input tokens + 2k output, roughly
  **$0.01 a save** (Flash-Lite about a third of that); a 30-save demo is well under $1. Prices change, check
  the Gemini pricing page first.
- Before the demo: one dry run with 3 phones at once, watch `docker logs -f reelbrain`.
- New demo users sign in with Google and get a personal space via `/v1/me`, as today; Firestore rules unchanged.

## Steps only you can do

1. Sign up for Oracle Cloud (card for identity check), pick the **home region** (Jeddah or Dubai).
2. Optional but recommended: upgrade to Pay As You Go, and add the $1 budget alert.
3. Create the A1 instance (Ubuntu 24.04, 2 OCPU / 12 GB, your SSH public key), note its public IP;
   or tell me to walk you through it field by field.
4. Make a DuckDNS account, create the name, point it at the VM's IP.
5. Generate the Firebase service-account key (above) and keep the JSON somewhere I can copy from.
6. Give me SSH access (the private key path on this PC) so I can set the VM up.

## After approval, in order

1. Code changes 1–4, backend tests (`.venv\Scripts\python -m pytest`), ruff clean.
2. On the VM: Docker, Caddy, iptables/security list, `/etc/reelbrain/{env,sa.json}` (Gemini key piped
   from `backend/.env` over SSH, never printed), copy the code, `setup.sh`.
3. `https://<name>.duckdns.org/health`, and `config/backend` shows the fixed URL.
4. Copy existing frames from `backend/data/frames` to the VM so old saves keep their pictures.
5. One real save from the S22 (wireless adb) end to end, frame visible; Recall run once by hand.
6. Update P0-05 in `BUILD_PLAN.md`, commit `B1: …`.

Not in B1: deploy on push from GitHub Actions, backups of the VM disk (only transient videos and
frames live there; Firestore holds the data), a bought domain.
