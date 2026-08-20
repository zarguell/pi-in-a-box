# =============================================================================
# pi-in-a-box — Dockerfile
# =============================================================================
# Multi-stage build: builder installs npm packages, final stage is runtime.
# =============================================================================

ARG NODE_VERSION=22
ARG BASE_IMAGE=node:${NODE_VERSION}-bookworm-slim

# ---------------------------------------------------------------------------
# Stage 1: Builder — install global npm packages
# ---------------------------------------------------------------------------
FROM ${BASE_IMAGE} AS builder

ARG PI_VERSION=0.84.2
ARG DASHBOARD_VERSION=0.7.0
ARG SUBAGENTS_VERSION=0.52.0
ARG GOAL_VERSION=0.6.0
ARG BROWSER_NATIVE_VERSION=0.3.0
ARG SKILLFUL_VERSION=latest
ARG PROMPT_TEMPLATE_MODEL_VERSION=latest
ARG BTW_VERSION=latest
ARG REACTOR_VERSION=0.2.3
ARG TARGETPLATFORM

# Install build essentials for native npm modules
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 make g++ git ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

# Install Pi, dashboard, and reactor globally
RUN npm install -g --ignore-scripts \
    "@earendil-works/pi-coding-agent@${PI_VERSION}" \
    "@blackbelt-technology/pi-agent-dashboard@${DASHBOARD_VERSION}" \
    "pi-reactor@${REACTOR_VERSION}"

# ---------------------------------------------------------------------------
# Stage 2: Extension installer — pi must be on PATH to run `pi install`
# ---------------------------------------------------------------------------
FROM builder AS extensions

ARG SUBAGENTS_VERSION=0.52.0
ARG GOAL_VERSION=0.6.0
ARG BROWSER_NATIVE_VERSION=0.3.0
ARG SKILLFUL_VERSION=latest
ARG PROMPT_TEMPLATE_MODEL_VERSION=latest
ARG BTW_VERSION=latest
ARG REACTOR_VERSION=0.2.3

# Extensions install into ~/.pi/ which is the user's home.
# We install as root during build, then copy the result.
ENV HOME=/root

# Install extensions via Pi's package mechanism
# Core bundle (always installed):
#   pi-subagents: subagent delegation
#   @capyup/pi-goal: durable goal execution
#   pi-skillful: project/ancestor skill discovery and invocation
#   pi-prompt-template-model: slash-command model/skill workflows
#   @piex-dev/btw: out-of-band questions without session pollution
#   pi-reactor: cron/webhook triggers, durable queue, notifications
RUN pi install "npm:pi-subagents@${SUBAGENTS_VERSION}" && \
    pi install "npm:@capyup/pi-goal@${GOAL_VERSION}" && \
    pi install "npm:pi-skillful@${SKILLFUL_VERSION}" && \
    pi install "npm:pi-prompt-template-model@${PROMPT_TEMPLATE_MODEL_VERSION}" && \
    pi install "npm:@piex-dev/btw@${BTW_VERSION}" && \
    pi install "npm:pi-reactor@${REACTOR_VERSION}" && \
    echo "All extensions installed successfully" && \
    pi --version

# ---------------------------------------------------------------------------
# Stage 3: Runtime — minimal final image
# ---------------------------------------------------------------------------
FROM ${BASE_IMAGE} AS runtime

LABEL org.opencontainers.image.title="pi-in-a-box"
LABEL org.opencontainers.image.description="Self-hosted, Docker-first Pi coding agent environment with dashboard, subagents, goals, and browser automation."
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source="https://github.com/zarguell/pi-in-a-box"

# Runtime OS dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        curl \
        ca-certificates \
        git \
        python3 \
        python3-pip \
        procps \
        jq \
        # Chromium dependencies for browser automation
        chromium \
        fonts-liberation \
        libasound2 \
        libatk-bridge2.0-0 \
        libatk1.0-0 \
        libcups2 \
        libdbus-1-3 \
        libdrm2 \
        libgbm1 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libxcomposite1 \
        libxdamage1 \
        libxrandr2 \
        xdg-utils && \
    rm -rf /var/lib/apt/lists/*

# Copy Node.js, npm, pi, and dashboard from builder
COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy installed extensions from the extensions stage
COPY --from=extensions /root/.pi /tmp/pi-home-build

# Set up non-root user (base image has node:1000 — create piuser with 1001)
ARG PUID=1001
ARG PGID=1001
RUN groupadd -g ${PGID} piuser 2>/dev/null || true && \
    useradd -u ${PUID} -g piuser -m -s /bin/bash piuser 2>/dev/null || \
    usermod -g piuser -s /bin/bash piuser 2>/dev/null || true

# Copy entrypoint and scripts
COPY docker/entrypoint.sh /entrypoint.sh
COPY docker/entrypoint-reactor.sh /entrypoint-reactor.sh
COPY docker/entrypoint-reactor-webhook.sh /entrypoint-reactor-webhook.sh
COPY docker/install-extensions.sh /usr/local/bin/install-extensions.sh
COPY scripts/doctor.sh /usr/local/bin/pi-in-a-box-doctor
RUN chmod +x /entrypoint.sh /entrypoint-reactor.sh /entrypoint-reactor-webhook.sh \
    /usr/local/bin/install-extensions.sh /usr/local/bin/pi-in-a-box-doctor

# Create persistent directory structure
RUN mkdir -p /data/pi-home /data/dashboard /data/browser /data/pi-reactor /workspace && \
    chown -R piuser:piuser /data /workspace

# Copy the pi-home build artifacts to final location
RUN cp -a /tmp/pi-home-build/. /data/pi-home/ && \
    rm -rf /tmp/pi-home-build && \
    chown -R piuser:piuser /data/pi-home

# Set environment
ENV HOME=/data/pi-home
ENV PI_HOME=/data/pi-home
ENV PI_REACTOR_DIR=/data/pi-reactor
ENV PATH="/usr/local/bin:${HOME}/.npm-global/bin:${PATH}"
ENV NODE_ENV=production

WORKDIR /workspace
EXPOSE 8000

# Health check: try to reach the dashboard HTTP server
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -sf http://127.0.0.1:8000/ > /dev/null || exit 1

# Entrypoint runs as root to set up volumes/permissions, then drops to piuser
USER root
ENTRYPOINT ["/entrypoint.sh"]
