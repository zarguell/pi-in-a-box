#!/usr/bin/env bash
# =============================================================================
# pi-in-a-box — Reactor Daemon Entrypoint
# =============================================================================
set -euo pipefail

PIAB_PORT="${PIAB_PORT:-8000}"
PIAB_PI_HOME="${PIAB_PI_HOME:-/data/pi-home}"
PI_REACTOR_DIR="${PI_REACTOR_DIR:-/data/pi-reactor}"
PIAB_WORKSPACE="${PIAB_WORKSPACE:-/workspace}"

# Reactor configuration (translated from PIAB_* to pi-reactor flags)
PIAB_REACTOR_CONCURRENCY="${PIAB_REACTOR_CONCURRENCY:-2}"
PIAB_REACTOR_DAILY_TOKEN_CAP="${PIAB_REACTOR_DAILY_TOKEN_CAP:-}"
PIAB_REACTOR_RETENTION_DAYS="${PIAB_REACTOR_RETENTION_DAYS:-30}"
PIAB_REACTOR_SHUTDOWN_GRACE="${PIAB_REACTOR_SHUTDOWN_GRACE:-60s}"

export HOME="${PIAB_PI_HOME}"
export PI_HOME="${PIAB_PI_HOME}"
export PI_REACTOR_DIR="${PI_REACTOR_DIR}"

cleanup() {
    echo "[pi-reactor] Received shutdown signal, draining..."
    # pi-reactor serve handles SIGTERM and drains running jobs
    exit 0
}
trap cleanup SIGTERM SIGINT

ensure_dirs() {
    local dirs=(
        "${PI_REACTOR_DIR}"
        "${PIAB_PI_HOME}"
        "${PIAB_PI_HOME}/.pi"
        "${PIAB_PI_HOME}/.pi/extensions"
        "${PIAB_PI_HOME}/.pi/sessions"
    )
    for dir in "${dirs[@]}"; do
        mkdir -p "${dir}"
        chown -R "$(id -u):$(id -g)" "${dir}" 2>/dev/null || true
    done
    # Restrict credential file permissions
    find "${PI_REACTOR_DIR}" -name "*.key" -o -name "*.secret" -o -name "*.pem" 2>/dev/null | \
        xargs chmod 0600 2>/dev/null || true
}

main() {
    echo "============================================="
    echo " pi-in-a-box — Reactor Daemon"
    echo " $(pi-reactor --version 2>/dev/null || echo 'Reactor version unknown')"
    echo "============================================="

    ensure_dirs

    # Build serve flags
    local flags=("--concurrency" "${PIAB_REACTOR_CONCURRENCY}")

    if [[ -n "${PIAB_REACTOR_DAILY_TOKEN_CAP}" ]]; then
        flags+=("--daily-token-cap" "${PIAB_REACTOR_DAILY_TOKEN_CAP}")
    fi

    flags+=("--retention" "${PIAB_REACTOR_RETENTION_DAYS}d")
    flags+=("--shutdown-grace" "${PIAB_REACTOR_SHUTDOWN_GRACE}")

    echo "[pi-reactor] Starting daemon: pi-reactor serve ${flags[*]}"
    echo "[pi-reactor] Data dir: ${PI_REACTOR_DIR}"
    echo "[pi-reactor] Pi home: ${PIAB_PI_HOME}"

    exec pi-reactor serve "${flags[@]}"
}

main "$@"
