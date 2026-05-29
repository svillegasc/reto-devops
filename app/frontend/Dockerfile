# syntax=docker/dockerfile:1
###############################################################################
# Frontend (Nginx) — multi-stage build
#   Stage 1 "builder": validates and pre-compresses static assets (gzip), so
#                      Nginx serves smaller payloads with less runtime CPU.
#   Stage 2 "runtime": nginx-unprivileged base — runs as non-root (uid 101) and
#                      listens on 8080 by default. Only the final assets +
#                      config land in the image; no build tools ship.
###############################################################################

# ---- Stage 1: builder -------------------------------------------------------
FROM alpine:3.21 AS builder

WORKDIR /build
RUN apk add --no-cache gzip
COPY html/ ./html/

# Pre-compress text assets (kept alongside originals via -k) for gzip_static.
RUN find ./html -type f \( -name '*.html' -o -name '*.css' -o -name '*.js' \) \
    -exec gzip -9 -k {} \;

# ---- Stage 2: runtime -------------------------------------------------------
# nginx-unprivileged runs as non-root (uid 101) and listens on 8080 — a great
# fit for restrictive Pod SecurityContexts (runAsNonRoot, no NET_BIND).
FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime

# Replace the default site config with ours (reverse proxy to backend).
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Ship the (pre-compressed) static assets.
COPY --from=builder /build/html /usr/share/nginx/html

EXPOSE 8080
# USER is already 101 (non-root) in the base image; declared here for clarity.
USER 101
