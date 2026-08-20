#!/usr/bin/env bash
# =============================================================================
# pi-in-a-box — Reactor Smoke Test
# =============================================================================
# Verifies pi-reactor is functional inside the container.
# =============================================================================
set -euo pipefail

echo "[smoke-test-reactor] Starting reactor smoke tests..."
FAILURES=0

check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "  [PASS] ${desc}"
    else
        echo "  [FAIL] ${desc}"
        ((FAILURES++)) || true
    fi
}

# --- Binary checks ---
echo "[smoke-test-reactor] Checking binaries..."
check "pi-reactor is on PATH" command -v pi-reactor

# --- Version check ---
echo "[smoke-test-reactor] Checking version..."
REACTOR_VERSION=$(pi-reactor --version 2>/dev/null || echo "")
if [[ -n "${REACTOR_VERSION}" ]]; then
    echo "  [PASS] pi-reactor version: ${REACTOR_VERSION}"
else
    echo "  [FAIL] Could not determine pi-reactor version"
    ((FAILURES++)) || true
fi

# --- Extension check ---
echo "[smoke-test-reactor] Checking extension..."
if pi install --list 2>/dev/null | grep -q "pi-reactor"; then
    echo "  [PASS] pi-reactor extension installed"
else
    echo "  [WARN] pi-reactor extension not in list (may still work)"
fi

# --- Data directory ---
echo "[smoke-test-reactor] Checking data directory..."
REACTOR_DIR="${PI_REACTOR_DIR:-/data/pi-reactor}"
if [[ -d "${REACTOR_DIR}" ]] && [[ -w "${REACTOR_DIR}" ]]; then
    echo "  [PASS] ${REACTOR_DIR} is writable"
else
    echo "  [FAIL] ${REACTOR_DIR} not writable or missing"
    ((FAILURES++)) || true
fi

# --- Status check (requires daemon running) ---
echo "[smoke-test-reactor] Checking daemon status..."
if pi-reactor status >/dev/null 2>&1; then
    echo "  [PASS] pi-reactor daemon is responsive"
else
    echo "  [WARN] pi-reactor daemon not running (expected if service not started yet)"
fi

# --- Doctor check ---
echo "[smoke-test-reactor] Running doctor..."
if pi-reactor doctor >/dev/null 2>&1; then
    echo "  [PASS] pi-reactor doctor passed"
else
    echo "  [WARN] pi-reactor doctor reported issues (may need configuration)"
fi

# --- Result ---
echo ""
if [[ ${FAILURES} -eq 0 ]]; then
    echo "[smoke-test-reactor] All tests passed."
    exit 0
else
    echo "[smoke-test-reactor] ${FAILURES} test(s) failed."
    exit 1
fi
