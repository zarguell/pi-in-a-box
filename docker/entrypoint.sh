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
# Bind address *inside* the container. Must be 0.0.0.0 so Docker's
# bridged port publishing (127.0.0.1:${PIAB_PORT}->container:8000 via eth0)
# can reach the server. Host-side loopback protection is provided by
# compose.yaml's "127.0.0.1:8000:8000" mapping, not by the dashboard bind.
# Override to 127.0.0.1 only when using host networking.
PIAB_BIND_HOST="${PIAB_BIND_HOST:-0.0.0.0}"
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
# Ensure the Docker bridge gateway is in trustedNetworks so a host browser
# reaching the dashboard through Docker's port-forward (e.g. 127.0.0.1:8000 ->
# container:8000, socket peer 172.19.0.1) is not rejected by the upstream
# localhost-guard (createNetworkGuard). Opt-out with PIAB_AUTO_TRUST_DOCKER_BRIDGE=false.
# Seeded into the persisted config.json before pi-dashboard reads it so no
# authenticated PUT /api/config round-trip is needed. The mutation is
# idempotent and preserves user-configured entries.
# ---------------------------------------------------------------------------
seed_trusted_bridge() {
    [[ "${PIAB_AUTO_TRUST_DOCKER_BRIDGE:-true}" == "false" ]] && return 0

    local config_dir="${PIAB_PI_HOME}/.pi/dashboard"
    local config_file="${config_dir}/config.json"
    mkdir -p "${config_dir}"
    export SEED_BRIDGE_CONFIG_FILE="${config_file}"

    node -e '
      const fs = require("fs");
      const os = require("os");
      const p = process.env.SEED_BRIDGE_CONFIG_FILE;
      let cfg = {};
      try { cfg = JSON.parse(fs.readFileSync(p, "utf8")); } catch (e) {}
      const existing = Array.isArray(cfg.trustedNetworks) ? cfg.trustedNetworks : [];
      const bridgeSubnets = new Set();
      for (const nets of Object.values(os.networkInterfaces() || {})) {
        for (const n of nets || []) {
          if (n.family !== "IPv4" || n.internal) continue;
          if (!n.address.startsWith("172.")) continue;
          const octets = n.address.split(".");
          bridgeSubnets.add(`${octets[0]}.${octets[1]}.0.0/16`);
        }
      }
      if (bridgeSubnets.size === 0) bridgeSubnets.add("172.19.0.0/16");
      let changed = false;
      for (const s of bridgeSubnets) {
        if (!existing.includes(s)) { existing.push(s); changed = true; }
      }
      if (!changed) process.exit(0);
      cfg.trustedNetworks = existing;
      fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + "\n");
      console.log("[pi-in-a-box] trustedNetworks += " + Array.from(bridgeSubnets).join(", "));
    ' 2>&1 || true

    chown -R "${PI_USER}:${PI_USER}" "${config_dir}" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Upstream 0.7.0 dashboard bakes 8 plugins into pi-dashboard-web's build
# hash (61102e9) but runtime discoverPlugins() in the Docker image finds 0
# (the server package has no plugin deps) so /api/health.bundleHash is
# always 4f53cda and the amber "Dashboard plugins were updated" banner is
# permanently stuck — Refresh can never reconcile it, dismiss is per-tab.
# Fix by bridging the missing plugins into the server's discovery path
# (installed plugins dir) so runtime hash matches the baked one. Falls
# back to patching the served index.js if node_modules layout changes.
# ---------------------------------------------------------------------------
suppress_stale_plugin_banner() {
    local dash_root="/usr/local/lib/node_modules/@blackbelt-technology/pi-agent-dashboard"
    local plugins_target="${PIAB_PI_HOME}/.pi/dashboard/plugins"
    local installed=false

    # 1) Bridge the 8 bundled plugins into the "installed plugins" dir that
    #    discoverPlugins() scans (second search path after monorepo packages/).
    #    Without this the banner is always stuck on Docker/npm installs.
    if [[ -d "${dash_root}/node_modules/@blackbelt-technology/pi-dashboard-web" ]]; then
        mkdir -p "${plugins_target}"
        local any=false
        for pkg in "${dash_root}"/node_modules/@blackbelt-technology/pi-dashboard-*-plugin; do
            [[ -d "${pkg}" ]] || continue
            local name
            name="$(basename "${pkg}")"
            local link="${plugins_target}/${name}"
            if [[ ! -e "${link}" ]]; then
                ln -s "${pkg}" "${link}" 2>/dev/null || cp -a "${pkg}" "${link}" 2>/dev/null || true
                any=true
            fi
        done
        if [[ "${any}" == "true" ]]; then
            installed=true
            chown -R "${PI_USER}:${PI_USER}" "${plugins_target}" 2>/dev/null || true
            echo "[pi-in-a-box] bridged dashboard plugins into ${plugins_target}"
        fi
    fi

    # Verify the fix actually reconciled the hashes (compare baked hash in
    # the served JS with /api/health once the server is up is too late here
    # at startup — do it after start_dashboard begins). If it did not, fall
    # back to rewriting the minified stale-banner compare in the served JS
    # (t(d.bundleHash!==e2)) so it ignores the empty-registry hash.
    if [[ "${installed}" == "true" ]]; then
        return 0
    fi

    local idx="${dash_root}/node_modules/@blackbelt-technology/pi-dashboard-web/dist/assets/index-CWy7aTzt.js"
    [[ -f "${idx}" ]] || return 0
    grep -q "pi-in-a-box: suppress empty-registry staleness" "${idx}" 2>/dev/null && return 0
    node -e '
      const fs = require("fs");
      const p = process.argv[1];
      const EMPTY = "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945";
      let s = fs.readFileSync(p, "utf8");
      const before = s;
      s = s.replace(
        /t\(d\.bundleHash!==e2\)/g,
        `t(d.bundleHash!==e2&&d.bundleHash!=="${EMPTY}")`
      );
      if (s !== before) {
        s = "/* pi-in-a-box: suppress empty-registry staleness (upstream 0.7.0) */\n" + s;
        fs.writeFileSync(p, s);
        console.log("[pi-in-a-box] patched stale-plugin banner (empty-registry hash)");
      }
    ' "${idx}" 2>&1 || true
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
    seed_trusted_bridge
    suppress_stale_plugin_banner
    seed_public_url
    start_dashboard
}

main "$@"
