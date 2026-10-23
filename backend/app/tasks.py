"""Hands a save to /internal/process: Cloud Tasks in the cloud, a background thread locally."""

import json
import logging
import os
import threading
import time

from app.pipeline.extract import Transient
from app.pipeline.process import process

QUEUE = os.environ.get("TASKS_QUEUE")  # projects/<p>/locations/<r>/queues/<q>
log = logging.getLogger("reelbrain.tasks")


def enqueue(save_id: str) -> None:
    if QUEUE:
        from google.cloud import tasks_v2

        tasks_v2.CloudTasksClient().create_task(
            parent=QUEUE,
            task={
                "http_request": {
                    "http_method": tasks_v2.HttpMethod.POST,
                    "url": f"{os.environ['PUBLIC_URL']}/internal/process",
                    "headers": {"Content-Type": "application/json"},
                    "body": json.dumps({"save_id": save_id}).encode(),
                    "oidc_token": {
                        "service_account_email": os.environ["TASKS_SERVICE_ACCOUNT"],
                        "audience": os.environ["TASKS_AUDIENCE"],
                    },
                }
            },
        )
        return
    threading.Thread(target=_run_local, args=(save_id,), daemon=True).start()


def _run_local(save_id: str) -> None:
    # Same retry shape as the Cloud Tasks queue: 3 attempts, exponential backoff.
    for attempt in range(3):
        try:
            process(save_id, attempt)
            return
        except Transient:
            time.sleep(10 * 2**attempt)
        except Exception:
            log.exception("save=%s crashed", save_id)
            return
