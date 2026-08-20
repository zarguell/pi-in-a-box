#!/usr/bin/env bash
# =============================================================================
# pi-in-a-box doctor — Environment diagnostics
# =============================================================================
# Validates that the container environment is correctly configured.
# Exit 0 = all checks pass; exit 1 = one or more failures.
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; ((WARNINGS++)) || true; }
fail() { echo -e "  ${RED}✗${NC} $1"; ((ERRORS++)) || true; }

echo "============================================="
echo " pi-in-a-box doctor"
echo "============================================="
echo ""

# --- Pi Reactor ---
echo "[1/8] Pi Reactor"
if command -v pi-reactor &>/dev/null; then
    pass "pi-reactor found: $(pi-reactor --version 2>/dev/null || echo 'unknown version')"
else
    fail "pi-reactor not found on PATH"
fi

if pi install --list 2>/dev/null | grep -q "pi-reactor"; then
    pass "pi-reactor extension installed"
else
    warn "pi-reactor extension not found"
fi

if [[ -d "${PI_REACTOR_DIR:-/data/pi-reactor}" ]]; then
    pass "Reactor data directory exists: ${PI_REACTOR_DIR:-/data/pi-reactor}"
else
    warn "Reactor data directory not found"
fi

# --- Pi ---
echo "[2/8] Pi agent"
if command -v pi &>/dev/null; then
    pass "pi found: $(pi --version 2>/dev/null || echo 'unknown version')"
else
    fail "pi not found on PATH"
fi

# --- Node.js ---
echo "[3/8] Node.js"
if command -v node &>/dev/null; then
    pass "Node.js found: $(node --version)"
else
    fail "Node.js not found on PATH"
fi

# --- Dashboard ---
echo "[4/8] Dashboard"
if command -v pi-dashboard &>/dev/null; then
    pass "pi-dashboard found"
else
    fail "pi-dashboard not found on PATH"
fi

# Dashboard port check
if curl -sf "http://127.0.0.1:${PIAB_PORT:-8000}/" >/dev/null 2>&1; then
    pass "Dashboard responding on port ${PIAB_PORT:-8000}"
else
    warn "Dashboard not responding on port ${PIAB_PORT:-8000} (may not be started yet)"
fi

# --- Extensions ---
echo "[5/8] Extensions"
if pi install --list 2>/dev/null | grep -q "pi-subagents"; then
    pass "pi-subagents installed"
else
    warn "pi-subagents not found (may need installation)"
fi

if pi install --list 2>/dev/null | grep -q "pi-goal"; then
    pass "pi-goal installed"
else
    warn "pi-goal not found (may need installation)"
fi

if pi install --list 2>/dev/null | grep -q "pi-skillful"; then
    pass "pi-skillful installed"
else
    warn "pi-skillful not found (may need installation)"
fi

if pi install --list 2>/dev/null | grep -q "pi-prompt-template-model"; then
    pass "pi-prompt-template-model installed"
else
    warn "pi-prompt-template-model not found (may need installation)"
fi

if pi install --list 2>/dev/null | grep -q "btw"; then
    pass "@piex-dev/btw installed"
else
    warn "@piex-dev/btw not found (may need installation)"
fi

if [[ "${PIAB_BROWSER_ENABLED:-false}" == "true" ]]; then
    if pi install --list 2>/dev/null | grep -q "pi-agent-browser-native"; then
        pass "pi-agent-browser-native installed"
    else
        warn "pi-agent-browser-native not found (browser enabled but extension missing)"
    fi

    if command -v agent-browser &>/dev/null; then
        pass "agent-browser found on PATH"
    else
        warn "agent-browser not found on PATH (browser extension may not work)"
    fi

    if command -v chromium &>/dev/null || command -v chromium-browser &>/dev/null; then
        pass "Chromium found"
    else
        warn "Chromium not found (browser extension may not work)"
    fi
else
    warn "Browser automation disabled (PIAB_BROWSER_ENABLED=false)"
fi

# --- Persistence ---
echo "[6/8] Persistence"
for dir in /data/pi-home /data/dashboard /workspace; do
    if [[ -d "${dir}" ]]; then
        if [[ -w "${dir}" ]]; then
            pass "${dir} exists and is writable"
        else
            fail "${dir} exists but is NOT writable"
        fi
    else
        fail "${dir} does not exist"
    fi
done

if [[ "${PIAB_BROWSER_ENABLED:-false}" == "true" ]]; then
    if [[ -d "/data/browser" ]] && [[ -w "/data/browser" ]]; then
        pass "/data/browser exists and is writable"
    else
        warn "/data/browser not available"
    fi
fi

# --- Git ---
echo "[7/8] Git"
if command -v git &>/dev/null; then
    pass "git found: $(git --version)"
else
    warn "git not found (some features may be limited)"
fi

# --- Python ---
echo "[8/8] Python"
if command -v python3 &>/dev/null; then
    pass "python3 found: $(python3 --version)"
else
    warn "python3 not found"
fi

if command -v pip3 &>/dev/null; then
    pass "pip3 found"
else
    warn "pip3 not found"
fi

echo ""
echo "============================================="
if [[ ${ERRORS} -eq 0 ]]; then
    echo -e " ${GREEN}All checks passed.${NC}"
    if [[ ${WARNINGS} -gt 0 ]]; then
        echo -e " ${YELLOW}${WARNINGS} warning(s).${NC}"
    fi
    echo "============================================="
    exit 0
else
    echo -e " ${RED}${ERRORS} error(s), ${YELLOW}${WARNINGS} warning(s).${NC}"
    echo "============================================="
    exit 1
fi
