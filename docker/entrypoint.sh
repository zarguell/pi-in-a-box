#!/usr/bin/env bash
# =============================================================================
# pi-in-a-box — Container Entrypoint
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PIAB_PORT="${PIAB_PORT:-8000}"
PIAB_PI_HOME="${PIAB_PI_HOME:-/data/pi-home}"
PIAB_BROWSER_ENABLED="${PIAB_BROWSER_ENABLED:-false}"
PIAB_WORKSPACE="${PIAB_WORKSPACE:-/workspace}"

# Ensure HOME points to persistent storage
export HOME="${PIAB_PI_HOME}"
export PI_HOME="${PIAB_PI_HOME}"

# ---------------------------------------------------------------------------
# Signal handling — forward SIGTERM/SIGINT to child process
# ---------------------------------------------------------------------------
cleanup() {
    echo "[pi-in-a-box] Received shutdown signal, stopping..."
    if [[ -n "${DASHBOARD_PID:-}" ]]; then
        kill -TERM "${DASHBOARD_PID}" 2>/dev/null || true
        wait "${DASHBOARD_PID}" 2>/dev/null || true
    fi
    echo "[pi-in-a-box] Shutdown complete."
    exit 0
}
trap cleanup SIGTERM SIGINT

# ---------------------------------------------------------------------------
# Ensure persistent directories are writable
# ---------------------------------------------------------------------------
ensure_dirs() {
    local dirs=(
        "${PIAB_PI_HOME}"
        "${PIAB_PI_HOME}/.pi"
        "${PIAB_PI_HOME}/.pi/extensions"
        "${PIAB_PI_HOME}/.pi/sessions"
        "${PIAB_PI_HOME}/.pi/goals"
        "/data/dashboard"
        "/workspace"
    )

    if [[ "${PIAB_BROWSER_ENABLED}" == "true" ]]; then
        dirs+=("/data/browser")
    fi

    for dir in "${dirs[@]}"; do
        mkdir -p "${dir}"
        chown -R "$(id -u):$(id -g)" "${dir}"
    done
}

# ---------------------------------------------------------------------------
# Configure Pi settings
# ---------------------------------------------------------------------------
configure_pi() {
    local settings_dir="${PIAB_PI_HOME}/.pi"
    local settings_file="${settings_dir}/settings.json"

    mkdir -p "${settings_dir}"

    # Write settings.json if it doesn't exist
    if [[ ! -f "${settings_file}" ]]; then
        cat > "${settings_file}" <<'SETTINGS'
{
  "packages": []
}
SETTINGS
        echo "[pi-in-a-box] Created default Pi settings."
    fi

    # Set the working directory for Pi sessions
    if [[ -d "${PIAB_WORKSPACE}" ]]; then
        cd "${PIAB_WORKSPACE}" || true
    fi
}

# ---------------------------------------------------------------------------
# Start dashboard
# ---------------------------------------------------------------------------
start_dashboard() {
    echo "[pi-in-a-box] Starting dashboard on port ${PIAB_PORT}..."
    echo "[pi-in-a-box] Pi home: ${PIAB_PI_HOME}"
    echo "[pi-in-a-box] Workspace: ${PIAB_WORKSPACE}"
    echo "[pi-in-a-box] Browser automation: ${PIAB_BROWSER_ENABLED}"
    echo "[pi-in-a-box] Safety guards: ${PIAB_ENABLE_SAFETY_GUARDS:-true}"
    echo "[pi-in-a-box] Crew orchestration: ${PIAB_ENABLE_CREW:-false}"
    echo "[pi-in-a-box] Ralph loops: ${PIAB_ENABLE_RALPH:-false}"

    # Run pi-dashboard in foreground/server mode
    exec pi-dashboard start \
        --port "${PIAB_PORT}" \
        --host 0.0.0.0 \
        2>&1 &
    DASHBOARD_PID=$!

    # Wait for the dashboard to exit or be signaled
    wait "${DASHBOARD_PID}"
    local exit_code=$?

    echo "[pi-in-a-box] Dashboard exited with code ${exit_code}."
    exit "${exit_code}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo "============================================="
    echo " pi-in-a-box"
    echo " $(pi --version 2>/dev/null || echo 'Pi version unknown')"
    echo "============================================="

    ensure_dirs
    configure_pi
    start_dashboard
}

main "$@"
