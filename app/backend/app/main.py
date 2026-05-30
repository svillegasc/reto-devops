"""Backend API — reto-devops.

A minimal, dependency-light FastAPI service that the frontend (Nginx) proxies
its `/api/*` calls to. It is intentionally small so the container image stays
slim and the attack surface minimal.
"""
import os
import socket

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Build metadata is injected at image-build time via env vars so that every
# immutable image can report exactly which commit produced it.
APP_VERSION = os.getenv("APP_VERSION", "dev")
GIT_SHA = os.getenv("GIT_SHA", "unknown")

app = FastAPI(
    title="reto-devops Backend API",
    version=APP_VERSION,
    docs_url="/api/docs",
    openapi_url="/api/openapi.json",
)

# CORS is permissive here only because the frontend reaches the API through an
# in-cluster Nginx reverse proxy (same origin). Tighten in production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET"],
    allow_headers=["*"],
)


@app.get("/api/health")
def health() -> dict:
    """Liveness/readiness probe target. Cheap and side-effect free."""
    return {"status": "ok"}


@app.get("/api/info")
def info() -> dict:
    """Returns build + runtime metadata so the UI can prove which image runs."""
    return {
        "service": "backend",
        "version": APP_VERSION,
        "git_sha": GIT_SHA,
        "hostname": socket.gethostname(),
    }


@app.get("/api/message")
def message() -> dict:
    """The single business endpoint the frontend renders."""
    return {
        "message": "Hello from the reto-devops backend API 👋 Probando un cambio",
        "version": APP_VERSION,
        "git_sha": GIT_SHA,
    }
