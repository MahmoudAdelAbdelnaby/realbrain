# Reelbrain

Share a reel, get the knowledge. Specs live in [docs/](docs/).

| Path | What |
| --- | --- |
| `app/` | Flutter client |
| `backend/` | FastAPI service (Cloud Run) |
| `infra/` | Firestore rules, indexes, Cloud Run + Tasks config |
| `docs/` | PRD and build plan |
| `test/fixtures/reels.md` | The 20-reel test set |

## Backend

Python 3.12 (CI uses 3.12) and ffmpeg on PATH. Copy `backend/.env.example` to `backend/.env` and add your Gemini key.

```bash
cd backend
python -m venv .venv && .venv/Scripts/pip install -r requirements-dev.txt   # bin/ on macOS/Linux
.venv/Scripts/uvicorn app.main:app --reload   # http://127.0.0.1:8000/health
.venv/Scripts/pytest
.venv/Scripts/python -m scripts.extract_file reel.mp4 --caption "..."   # one real reel through Gemini
```

## App

```bash
cd app
flutter create --platforms=android,ios --project-name reelbrain .   # first time only: generates android/ and ios/
flutter run
```

Secrets go in `.env` files (git-ignored) locally and Secret Manager in the cloud. Never commit keys.
