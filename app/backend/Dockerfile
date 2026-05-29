# syntax=docker/dockerfile:1
###############################################################################
# Backend (FastAPI) — multi-stage build
#   Stage 1 "builder": installs Python deps into an isolated virtualenv.
#   Stage 2 "runtime": copies only the venv + app code onto a slim base and
#                      runs as a non-root user with no build toolchain present.
# This keeps the final image small and free of compilers/headers (reduced
# attack surface).
###############################################################################

# ---- Stage 1: builder -------------------------------------------------------
FROM python:3.12-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /build

# Build the venv in a layer that only changes when requirements change.
COPY requirements.txt .
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# ---- Stage 2: runtime -------------------------------------------------------
FROM python:3.12-slim AS runtime

# Build args turned into runtime metadata (see app/main.py).
ARG APP_VERSION=dev
ARG GIT_SHA=unknown

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    APP_VERSION=${APP_VERSION} \
    GIT_SHA=${GIT_SHA}

# Dedicated unprivileged user (uid 10001) — never run as root.
RUN groupadd --system --gid 10001 appuser \
    && useradd --system --uid 10001 --gid appuser --no-create-home appuser

WORKDIR /app

# Only the venv and the application source make it into the final image.
COPY --from=builder /opt/venv /opt/venv
COPY app/ ./app/

EXPOSE 8000
USER 10001

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/api/health').status==200 else 1)"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
