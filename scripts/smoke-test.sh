#!/usr/bin/env bash
# =============================================================================
# pi-in-a-box — Smoke Test
# =============================================================================
# Verifies the running container is functional.
# Designed to run inside the container after startup.
# =============================================================================
set -euo pipefail

echo "[smoke-test] Starting pi-in-a-box smoke tests..."
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
echo "[smoke-test] Checking binaries..."
check "pi is on PATH" command -v pi
check "pi-dashboard is on PATH" command -v pi-dashboard
check "node is on PATH" command -v node
check "git is on PATH" command -v git
check "python3 is on PATH" command -v python3
check "curl is on PATH" command -v curl

# --- Pi version ---
echo "[smoke-test] Checking Pi version..."
PI_VERSION=$(pi --version 2>/dev/null || echo "")
if [[ -n "${PI_VERSION}" ]]; then
    echo "  [PASS] Pi version: ${PI_VERSION}"
else
    echo "  [FAIL] Could not determine Pi version"
    ((FAILURES++)) || true
fi

# --- Dashboard HTTP check ---
echo "[smoke-test] Checking dashboard HTTP..."
PORT="${PIAB_PORT:-8000}"
if curl -sf "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
    echo "  [PASS] Dashboard responding on port ${PORT}"
else
    echo "  [FAIL] Dashboard not responding on port ${PORT}"
    ((FAILURES++)) || true
fi

# --- Persistence checks ---
echo "[smoke-test] Checking persistence directories..."
for dir in /data/pi-home /data/dashboard /workspace; do
    if [[ -d "${dir}" ]] && [[ -w "${dir}" ]]; then
        echo "  [PASS] ${dir} is writable"
    else
        echo "  [FAIL] ${dir} not writable or missing"
        ((FAILURES++)) || true
    fi
done

# --- Extension checks ---
echo "[smoke-test] Checking extensions..."
if pi install --list 2>/dev/null | grep -q "pi-subagents"; then
    echo "  [PASS] pi-subagents installed"
else
    echo "  [WARN] pi-subagents not in list (may still work)"
fi

if pi install --list 2>/dev/null | grep -q "pi-goal"; then
    echo "  [PASS] pi-goal installed"
else
    echo "  [WARN] pi-goal not in list (may still work)"
fi

if pi install --list 2>/dev/null | grep -q "pi-skillful"; then
    echo "  [PASS] pi-skillful installed"
else
    echo "  [WARN] pi-skillful not in list (may still work)"
fi

if pi install --list 2>/dev/null | grep -q "pi-prompt-template-model"; then
    echo "  [PASS] pi-prompt-template-model installed"
else
    echo "  [WARN] pi-prompt-template-model not in list (may still work)"
fi

if pi install --list 2>/dev/null | grep -q "btw"; then
    echo "  [PASS] @piex-dev/btw installed"
else
    echo "  [WARN] @piex-dev/btw not in list (may still work)"
fi

# --- Result ---
echo ""
if [[ ${FAILURES} -eq 0 ]]; then
    echo "[smoke-test] All tests passed."
    exit 0
else
    echo "[smoke-test] ${FAILURES} test(s) failed."
    exit 1
fi
