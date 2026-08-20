#!/usr/bin/env bash
# =============================================================================
# pi-in-a-box — Reactor Webhook Listener Entrypoint
# =============================================================================
set -euo pipefail

PIAB_PI_HOME="${PIAB_PI_HOME:-/data/pi-home}"
PI_REACTOR_DIR="${PI_REACTOR_DIR:-/data/pi-reactor}"
PIAB_WEBHOOK_PORT="${PIAB_WEBHOOK_PORT:-8787}"

export HOME="${PIAB_PI_HOME}"
export PI_HOME="${PIAB_PI_HOME}"
export PI_REACTOR_DIR="${PI_REACTOR_DIR}"

cleanup() {
    echo "[pi-reactor-webhook] Shutting down..."
    exit 0
}
trap cleanup SIGTERM SIGINT

main() {
    echo "============================================="
    echo " pi-in-a-box — Reactor Webhook Listener"
    echo "============================================="

    echo "[pi-reactor-webhook] Listening on port ${PIAB_WEBHOOK_PORT}"
    echo "[pi-reactor-webhook] Reactor dir: ${PI_REACTOR_DIR}"

    exec pi-reactor webhook --port "${PIAB_WEBHOOK_PORT}"
}

main "$@"
