import os
import tempfile

# Before app imports: local storage in a temp dir, dev auth, no cloud.
os.environ["AUTH_MODE"] = "dev"
os.environ["GEMINI_MIN_GAP_S"] = "0"
os.environ["DATA_DIR"] = tempfile.mkdtemp(prefix="reelbrain-test-")
for k in ("GCS_BUCKET", "TASKS_QUEUE", "USE_FIRESTORE"):
    os.environ.pop(k, None)
