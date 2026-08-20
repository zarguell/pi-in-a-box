#!/usr/bin/env bash
# =============================================================================
# pi-in-a-box — Container Entrypoint
# =============================================================================
set -uo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PIAB_PORT="${PIAB_PORT:-8000}"
PIAB_PI_HOME="${PIAB_PI_HOME:-/data/pi-home}"
PIAB_BROWSER_ENABLED="${PIAB_BROWSER_ENABLED:-false}"
PIAB_WORKSPACE="${PIAB_WORKSPACE:-/workspace}"
# Bind host for the dashboard server. Defaults to loopback to preserve the
# upstream "bound to loopback by default" security posture; set to 0.0.0.0 when
# the dashboard sits behind a same-host / network reverse proxy (e.g. traefik).
PIAB_BIND_HOST="${PIAB_BIND_HOST:-127.0.0.1}"
# Public base URL the dashboard advertises to its clients (the URL a browser
# actually reaches it on). Required when fronted by a reverse proxy that
# terminates TLS on a different port (e.g. https://pi.example.com:443 while the
# server listens on :8000). Seed pairing.publicBaseUrls so the client connects
# through the proxy instead of the internal :<port>.
PIAB_PUBLIC_URL="${PIAB_PUBLIC_URL:-}"

# Ensure HOME points to persistent storage
export HOME="${PIAB_PI_HOME}"
export PI_HOME="${PIAB_PI_HOME}"

# Dashboard runtime user created in the Dockerfile (ARG PUID/PGID, default 1001)
PI_USER="piuser"

# ---------------------------------------------------------------------------
# Signal handling — forward SIGTERM/SIGINT to the dashboard child
# ---------------------------------------------------------------------------
DASHBOARD_PID=""
cleanup() {
    echo "[pi-in-a-box] Received shutdown signal, stopping..."
    if [[ -n "${DASHBOARD_PID}" ]]; then
        kill -TERM "${DASHBOARD_PID}" 2>/dev/null || true
        wait "${DASHBOARD_PID}" 2>/dev/null || true
    fi
    exit 0
}
trap cleanup SIGTERM SIGINT

# ---------------------------------------------------------------------------
# Ensure persistent directories are writable by the dashboard user
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
        # Chown to the dashboard user (NOT root). The dashboard drops to this
        # user before writing, so root-owned dirs cause EACCES on first write.
        chown -R "${PI_USER}:${PI_USER}" "${dir}" 2>/dev/null || true
    done
}

# ---------------------------------------------------------------------------
# Configure Pi settings
# ---------------------------------------------------------------------------
configure_pi() {
    local settings_dir="${PIAB_PI_HOME}/.pi"
    local settings_file="${settings_dir}/settings.json"

    mkdir -p "${settings_dir}"

    if [[ ! -f "${settings_file}" ]]; then
        cat > "${settings_file}" <<'SETTINGS'
{
  "packages": []
}
SETTINGS
        chown "${PI_USER}:${PI_USER}" "${settings_file}" 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# Seed the dashboard's public base URL so the client connects through the
# reverse proxy (https://host:443) rather than the internal :<port>.
# ---------------------------------------------------------------------------
seed_public_url() {
    [[ -z "${PIAB_PUBLIC_URL}" ]] && return 0

    local config_dir="${PIAB_PI_HOME}/.pi/dashboard"
    local config_file="${config_dir}/config.json"
    mkdir -p "${config_dir}"
    export CONFIG_FILE="${config_file}"

    node -e '
      const fs = require("fs");
      const p = process.env.CONFIG_FILE;
      let cfg = {};
      try { cfg = JSON.parse(fs.readFileSync(p, "utf8")); } catch (e) {}
      cfg.pairing = cfg.pairing || {};
      cfg.pairing.publicBaseUrls = [process.env.PIAB_PUBLIC_URL];
      fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + "\n");
    ' || true

    chown -R "${PI_USER}:${PI_USER}" "${config_dir}" 2>/dev/null || true
    echo "[pi-in-a-box] Advertised public URL: ${PIAB_PUBLIC_URL}"
}

# ---------------------------------------------------------------------------
# Start dashboard (backgrounded) and keep the container alive while healthy
# ---------------------------------------------------------------------------
start_dashboard() {
    echo "[pi-in-a-box] Starting dashboard on port ${PIAB_PORT} (bind ${PIAB_BIND_HOST})..."
    echo "[pi-in-a-box] Pi home: ${PIAB_PI_HOME}"
    echo "[pi-in-a-box] Workspace: ${PIAB_WORKSPACE}"
    echo "[pi-in-a-box] Browser automation: ${PIAB_BROWSER_ENABLED}"
    echo "[pi-in-a-box] Safety guards: ${PIAB_ENABLE_SAFETY_GUARDS:-true}"
    echo "[pi-in-a-box] Crew orchestration: ${PIAB_ENABLE_CREW:-false}"
    echo "[pi-in-a-box] Ralph loops: ${PIAB_ENABLE_RALPH:-false}"

    # The upstream launcher prints a "readiness timeout" and exits at ~30s while
    # the server (jiti/TS-compiled) is still cold-booting; its server child is
    # detached and keeps booting. Run it in the background and own the lifecycle
    # here so the container stays up through the slow start and only exits when
    # the server is actually down.
    su -s /bin/bash "${PI_USER}" -c "
        export HOME='${PIAB_PI_HOME}'
        export PI_HOME='${PIAB_PI_HOME}'
        export PI_DASHBOARD_HOST='${PIAB_BIND_HOST}'
        exec pi-dashboard start --port '${PIAB_PORT}' --host '${PIAB_BIND_HOST}'
    " &
    DASHBOARD_PID=$!

    # Wait (up to ~10 min) for the server to come up past the cold-start compile.
    for _ in $(seq 1 120); do
        if curl -sf -o /dev/null "http://127.0.0.1:${PIAB_PORT}/api/health"; then
            break
        fi
        sleep 5
    done

    # Stay alive while the server is healthy; exit (and let the supervisor
    # restart) if it dies.
    while curl -sf -o /dev/null "http://127.0.0.1:${PIAB_PORT}/api/health"; do
        sleep 10
    done

    echo "[pi-in-a-box] server stopped; exiting."
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
    seed_public_url
    start_dashboard
}

main "$@"
