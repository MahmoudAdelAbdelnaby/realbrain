"""Firebase ID token check for every /v1 endpoint, and OIDC check for /internal."""

import os
from functools import cache

from fastapi import Header, HTTPException

# Local only: AUTH_MODE=dev accepts "Bearer dev" as uid "dev" (and "Bearer dev:<name>" as uid <name>,
# for tests with two people). Never set on Cloud Run or behind a public tunnel.
DEV = os.environ.get("AUTH_MODE") == "dev"


@cache
def firebase_app():
    import firebase_admin

    return firebase_admin.initialize_app(options={"projectId": os.environ.get("GOOGLE_CLOUD_PROJECT")})


def _bearer(authorization: str | None) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "missing bearer token")
    return authorization.removeprefix("Bearer ").strip()


def user(authorization: str | None = Header(None)) -> str:
    """FastAPI dependency: the caller's Firebase uid."""
    token = _bearer(authorization)
    if DEV and (token == "dev" or token.startswith("dev:")):
        return token.removeprefix("dev:")
    from firebase_admin import auth

    try:
        return auth.verify_id_token(token, firebase_app())["uid"]
    except Exception as e:
        raise HTTPException(401, "invalid token") from e


def cloud_tasks(authorization: str | None = Header(None)) -> None:
    """FastAPI dependency: only Cloud Tasks (OIDC token for our service account) may call /internal."""
    token = _bearer(authorization)
    if DEV and token == "dev":
        return
    from google.auth.transport import requests
    from google.oauth2 import id_token

    try:
        claims = id_token.verify_oauth2_token(
            token, requests.Request(), audience=os.environ["TASKS_AUDIENCE"]
        )
    except Exception as e:
        raise HTTPException(401, "invalid task token") from e
    if claims.get("email") != os.environ.get("TASKS_SERVICE_ACCOUNT"):
        raise HTTPException(403, "wrong caller")
