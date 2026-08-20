#!/usr/bin/env bash
# =============================================================================
# pi-in-a-box — Extension installer
# =============================================================================
# Installs extensions based on PIAB_ENABLE_* environment variables.
# Core extensions are always installed. Optional ones are opt-in.
# =============================================================================
set -euo pipefail

PIAB_PI_HOME="${PIAB_PI_HOME:-/data/pi-home}"
export HOME="${PIAB_PI_HOME}"
export PI_HOME="${PIAB_PI_HOME}"

echo "[install-extensions] Installing Pi extensions..."

# Extension versions (overridable via environment)
SUBAGENTS_VERSION="${PIAB_VERSION_SUBAGENTS:-0.52.0}"
GOAL_VERSION="${PIAB_VERSION_GOAL:-0.6.0}"
BROWSER_NATIVE_VERSION="${PIAB_VERSION_BROWSER_NATIVE:-0.3.0}"
SKILLFUL_VERSION="${PIAB_VERSION_SKILLFUL:-latest}"
PROMPT_TEMPLATE_MODEL_VERSION="${PIAB_VERSION_PROMPT_TEMPLATE_MODEL:-latest}"
BTW_VERSION="${PIAB_VERSION_BTW:-latest}"

# Enable/disable flags
PIAB_BROWSER_ENABLED="${PIAB_BROWSER_ENABLED:-false}"
PIAB_ENABLE_NOTIFICATIONS="${PIAB_ENABLE_NOTIFICATIONS:-false}"
PIAB_ENABLE_CREW="${PIAB_ENABLE_CREW:-false}"
PIAB_ENABLE_SAFETY_GUARDS="${PIAB_ENABLE_SAFETY_GUARDS:-true}"
PIAB_ENABLE_RALPH="${PIAB_ENABLE_RALPH:-false}"

install_ext() {
    local pkg="$1"
    local label="${2:-$1}"
    echo "[install-extensions] Installing ${label}..."
    if pi install "npm:${pkg}" 2>/dev/null; then
        echo "[install-extensions]   ✓ ${label} installed"
    else
        echo "[install-extensions]   ⚠ Failed to install ${label} (continuing)"
    fi
}

install_ext_versioned() {
    local pkg="$1"
    local ver="$2"
    local label="${3:-$1}"
    echo "[install-extensions] Installing ${label}@${ver}..."
    if pi install "npm:${pkg}@${ver}" 2>/dev/null; then
        echo "[install-extensions]   ✓ ${label} installed"
    else
        echo "[install-extensions]   ⚠ Failed to install ${label} (continuing)"
    fi
}

# --- Core bundle (always installed) ---
echo "[install-extensions] === Core Bundle ==="
install_ext_versioned "pi-subagents" "${SUBAGENTS_VERSION}" "pi-subagents"
install_ext_versioned "@capyup/pi-goal" "${GOAL_VERSION}" "pi-goal"
install_ext_versioned "pi-skillful" "${SKILLFUL_VERSION}" "pi-skillful"
install_ext_versioned "pi-prompt-template-model" "${PROMPT_TEMPLATE_MODEL_VERSION}" "pi-prompt-template-model"
install_ext_versioned "@piex-dev/btw" "${BTW_VERSION}" "pi-btw"

# --- Browser automation (opt-in) ---
echo ""
echo "[install-extensions] === Browser ==="
if [[ "${PIAB_BROWSER_ENABLED}" == "true" ]]; then
    install_ext_versioned "pi-agent-browser-native" "${BROWSER_NATIVE_VERSION}" "pi-agent-browser-native"
else
    echo "[install-extensions]   Browser automation disabled (PIAB_BROWSER_ENABLED=false)"
fi

# --- Safety guards (opt-in) ---
echo ""
echo "[install-extensions] === Safety ==="
if [[ "${PIAB_ENABLE_SAFETY_GUARDS}" == "true" ]]; then
    install_ext "safe-coder" "safe-coder"
else
    echo "[install-extensions]   Safety guards disabled (PIAB_ENABLE_SAFETY_GUARDS=false)"
fi

# --- Crew orchestration (opt-in) ---
echo ""
echo "[install-extensions] === Crew ==="
if [[ "${PIAB_ENABLE_CREW}" == "true" ]]; then
    install_ext "pi-crew" "pi-crew"
else
    echo "[install-extensions]   Crew orchestration disabled (PIAB_ENABLE_CREW=false)"
fi

# --- Ralph-style loops (opt-in) ---
echo ""
echo "[install-extensions] === Ralph ==="
if [[ "${PIAB_ENABLE_RALPH}" == "true" ]]; then
    echo "[install-extensions]   Installing pi-extensions (Ralph-style loop module)..."
    if pi install "git:github.com/tmustier/pi-extensions" 2>/dev/null; then
        echo "[install-extensions]   ✓ pi-extensions installed"
    else
        echo "[install-extensions]   ⚠ Failed to install pi-extensions (continuing)"
    fi
else
    echo "[install-extensions]   Ralph loops disabled (PIAB_ENABLE_RALPH=false)"
fi

# --- Summary ---
echo ""
echo "[install-extensions] === Summary ==="
if pi install --list 2>/dev/null; then
    echo "[install-extensions] Extension list above."
else
    echo "[install-extensions] Could not list installed packages."
fi
echo "[install-extensions] Done."
