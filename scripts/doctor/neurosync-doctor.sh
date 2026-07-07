#!/usr/bin/env bash
# NeuroSync Pro environment health check. Read-only: does not install,
# sync, build, flash, or deploy anything. Prints PASS/WARN/FAIL per check,
# a summary, and the exact corrective command for each non-PASS.
set -uo pipefail
# shellcheck source=scripts/common/lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

repo_root="$(ns_repo_root)"
cd "$repo_root" || exit 1

PASS=0
WARN=0
FAIL=0
DOCTOR_TMPDIR=""
UV_CACHE_TMPDIR=""

cleanup() {
  if [ -n "$DOCTOR_TMPDIR" ] && [ -d "$DOCTOR_TMPDIR" ]; then
    rm -rf "$DOCTOR_TMPDIR"
  fi
  if [ -n "$UV_CACHE_TMPDIR" ] && [ -d "$UV_CACHE_TMPDIR" ]; then
    rm -rf "$UV_CACHE_TMPDIR"
  fi
}
trap cleanup EXIT

check() {
  local status="$1" name="$2" detail="$3" fix="${4:-}"
  case "$status" in
    PASS) PASS=$((PASS+1)); printf '[PASS] %-32s %s\n' "$name" "$detail" ;;
    WARN) WARN=$((WARN+1)); printf '[WARN] %-32s %s\n' "$name" "$detail"
          [ -n "$fix" ] && printf '       fix: %s\n' "$fix" ;;
    FAIL) FAIL=$((FAIL+1)); printf '[FAIL] %-32s %s\n' "$name" "$detail"
          [ -n "$fix" ] && printf '       fix: %s\n' "$fix" ;;
  esac
}

echo "=== NeuroSync Pro doctor ==="
echo "Repo root: $repo_root"
echo

tmp_base="${TMPDIR:-/tmp}"
if DOCTOR_TMPDIR="$(mktemp -d "$tmp_base/neurosync-doctor.XXXXXX")"; then
  check PASS "doctor temp dir" "$DOCTOR_TMPDIR"
else
  check FAIL "doctor temp dir" "could not create under $tmp_base" "set TMPDIR to a writable directory"
fi

if [ -n "${UV_CACHE_DIR:-}" ]; then
  if mkdir -p "$UV_CACHE_DIR" 2>/dev/null && [ -w "$UV_CACHE_DIR" ]; then
    export UV_CACHE_DIR
    check PASS "uv cache" "$UV_CACHE_DIR"
  else
    check FAIL "uv cache" "UV_CACHE_DIR is not writable: $UV_CACHE_DIR" "set UV_CACHE_DIR to a writable directory"
  fi
else
  if UV_CACHE_TMPDIR="$(mktemp -d "$tmp_base/neurosync-uv-cache.XXXXXX")"; then
    export UV_CACHE_DIR="$UV_CACHE_TMPDIR"
    check PASS "uv cache" "$UV_CACHE_DIR"
  else
    check FAIL "uv cache" "could not create under $tmp_base" "set TMPDIR or UV_CACHE_DIR to a writable directory"
  fi
fi

# --- repository / git ------------------------------------------------
if [ -d "$repo_root/.git" ]; then
  check PASS "repository root" "$repo_root"
  if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
    check PASS "git status" "clean"
  else
    check WARN "git status" "uncommitted/untracked changes present" "git status"
  fi
else
  check FAIL "repository root" "not a git repository" "git init"
fi

# --- Python / uv -------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
  check PASS "python3" "$(python3 --version 2>&1)"
else
  check FAIL "python3" "not found" "install Python 3.11+"
fi

if command -v uv >/dev/null 2>&1; then
  check PASS "uv" "$(uv --version 2>&1)"
else
  check FAIL "uv" "not found" "curl -LsSf https://astral.sh/uv/install.sh | sh"
fi

if [ -d "$repo_root/.venv" ] && [ -f "$repo_root/uv.lock" ]; then
  check PASS "dependency sync" ".venv and uv.lock present"
else
  check WARN "dependency sync" ".venv or uv.lock missing" "uv sync"
fi

if [ -d "$repo_root/.venv" ]; then
  if uv run --no-sync ruff check . >"$DOCTOR_TMPDIR/ruff.log" 2>&1; then
    check PASS "ruff" "no issues"
  else
    check FAIL "ruff" "issues found (log: $DOCTOR_TMPDIR/ruff.log)" "uv run ruff check ."
  fi

  if uv run --no-sync mypy src >"$DOCTOR_TMPDIR/mypy.log" 2>&1; then
    check PASS "mypy" "no issues"
  else
    check FAIL "mypy" "issues found (log: $DOCTOR_TMPDIR/mypy.log)" "uv run mypy src"
  fi

  if uv run --no-sync pytest tests/unit -q >"$DOCTOR_TMPDIR/pytest.log" 2>&1; then
    check PASS "pytest" "unit tests pass"
  else
    check FAIL "pytest" "unit tests failing (log: $DOCTOR_TMPDIR/pytest.log)" "uv run pytest tests/unit -v"
  fi
else
  check WARN "ruff/mypy/pytest" "skipped (.venv missing)" "uv sync"
fi

# --- Codex ---------------------------------------------------------------
if command -v codex >/dev/null 2>&1; then
  check PASS "codex installation" "$(codex --version 2>&1)"
else
  check FAIL "codex installation" "not found" "curl -fsSL https://chatgpt.com/codex/install.sh | sh"
fi

if [ -f "$repo_root/.codex/config.toml" ]; then
  if python3 -c "import tomllib; tomllib.load(open('$repo_root/.codex/config.toml','rb'))" 2>/tmp/ns-doctor-toml.log; then
    check PASS ".codex/config.toml" "valid TOML"
  else
    check FAIL ".codex/config.toml" "invalid TOML" "review $repo_root/.codex/config.toml"
  fi
else
  check FAIL ".codex/config.toml" "missing" "see Phase 7 of docs/setup/SETUP-REPORT.md"
fi

# --- Claude project settings ----------------------------------------------
if [ -f "$repo_root/.claude/settings.json" ]; then
  if python3 -m json.tool "$repo_root/.claude/settings.json" >/dev/null 2>/tmp/ns-doctor-json.log; then
    check PASS ".claude/settings.json" "valid JSON"
  else
    check FAIL ".claude/settings.json" "invalid JSON" "review $repo_root/.claude/settings.json"
  fi
else
  check FAIL ".claude/settings.json" "missing" "see Phase 6 of docs/setup/SETUP-REPORT.md"
fi

# --- ESP-IDF ---------------------------------------------------------------
idf_current="$HOME/esp/esp-idf-current"
if [ -f "$idf_current/export.sh" ]; then
  idf_ver="$(cd "$idf_current" && git describe --tags 2>/dev/null || echo unknown)"
  check PASS "ESP-IDF installation" "$idf_ver at $idf_current"
else
  check FAIL "ESP-IDF installation" "not found at $idf_current" "see Phase 9 of docs/setup/SETUP-REPORT.md"
fi

if compgen -G "$HOME/.espressif/python_env/*/bin/python" >/dev/null 2>&1; then
  check PASS "ESP-IDF python env" "present"
else
  check FAIL "ESP-IDF python env" "missing (install.sh did not complete)" "sudo apt-get install -y libusb-1.0-0 && ~/esp/esp-idf-current/install.sh esp32"
fi

if [ -d "$repo_root/firmware/esp32/build" ] && [ -f "$repo_root/firmware/esp32/build/nsp_diagnostic.bin" ]; then
  check PASS "ESP32 firmware build" "build/nsp_diagnostic.bin present"
else
  check WARN "ESP32 firmware build" "not built yet" "make esp32-build"
fi

# --- dialout / serial ------------------------------------------------------
if id -nG "$USER" | tr ' ' '\n' | grep -qx dialout; then
  check PASS "dialout membership" "$USER is in dialout"
else
  check WARN "dialout membership" "$USER is NOT in dialout" "sudo usermod -aG dialout $USER (then restart WSL: wsl --shutdown from Windows)"
fi

shopt -s nullglob
serial_devices=(/dev/ttyUSB* /dev/ttyACM*)
shopt -u nullglob
if [ "${#serial_devices[@]}" -gt 0 ]; then
  check PASS "serial devices" "${serial_devices[*]}"
else
  check WARN "serial devices" "none present" "attach ESP32 and bind/attach via usbipd (see scripts/windows/)"
fi

if command -v usbipd.exe >/dev/null 2>&1; then
  check PASS "usbipd availability" "usbipd.exe on PATH"
else
  check WARN "usbipd availability" "usbipd.exe not found via WSL interop" "install usbipd-win on Windows; see docs/setup/manual-actions.md"
fi

# --- SSH / Raspberry Pi ------------------------------------------------
if grep -q '^Host neurosync-pi$' "$HOME/.ssh/config" 2>/dev/null; then
  check PASS "SSH alias" "Host neurosync-pi present in ~/.ssh/config"
else
  check FAIL "SSH alias" "missing" "see Phase 12 of docs/setup/SETUP-REPORT.md"
fi

ns_load_hardware_env
if ssh -o BatchMode=yes -o ConnectTimeout=5 "$NEUROSYNC_PI_HOST" true 2>/dev/null; then
  check PASS "Raspberry Pi reachability" "$NEUROSYNC_PI_HOST reachable"
  remote_arch="$(ssh -o BatchMode=yes "$NEUROSYNC_PI_HOST" uname -m 2>/dev/null || echo unknown)"
  check PASS "remote architecture" "$remote_arch"
  remote_storage="$(ssh -o BatchMode=yes "$NEUROSYNC_PI_HOST" "df -h / | tail -1" 2>/dev/null || echo unknown)"
  check PASS "remote storage" "$remote_storage"
  remote_python="$(ssh -o BatchMode=yes "$NEUROSYNC_PI_HOST" "python3 --version" 2>/dev/null || echo unknown)"
  check PASS "remote Python" "$remote_python"
else
  check WARN "Raspberry Pi reachability" "$NEUROSYNC_PI_HOST not reachable" "verify Pi is powered on and networked; see docs/setup/manual-actions.md"
  check WARN "remote architecture" "skipped (Pi unreachable)" "-"
  check WARN "remote storage" "skipped (Pi unreachable)" "-"
  check WARN "remote Python" "skipped (Pi unreachable)" "-"
fi

# --- required docs / scripts / permissions --------------------------------
required_docs=(
  "AGENTS.md" "CLAUDE.md" "README.md"
  "docs/architecture/system-architecture.md"
  "docs/architecture/raspberry-pi-3-deviation.md"
  "docs/architecture/trust-boundaries.md"
  "docs/protocol/protocol-v1.md"
  "docs/protocol/state-machine.md"
  "docs/setup/system-audit.md"
)
missing_docs=()
for d in "${required_docs[@]}"; do
  [ -f "$repo_root/$d" ] || missing_docs+=("$d")
done
if [ "${#missing_docs[@]}" -eq 0 ]; then
  check PASS "required docs" "all present"
else
  check FAIL "required docs" "missing: ${missing_docs[*]}" "re-run the relevant setup phase"
fi

required_scripts=(
  scripts/esp32/detect.sh scripts/esp32/build.sh scripts/esp32/flash.sh
  scripts/esp32/monitor.sh scripts/esp32/flash-monitor.sh scripts/esp32/chip-info.sh
  scripts/pi/status.sh scripts/pi/inventory.sh scripts/pi/bootstrap.sh
  scripts/pi/deploy.sh scripts/pi/test.sh scripts/pi/logs.sh scripts/pi/shell.sh
  scripts/pi/install-services.sh scripts/pi/remove-services.sh
)
missing_scripts=()
not_executable=()
for s in "${required_scripts[@]}"; do
  if [ ! -f "$repo_root/$s" ]; then
    missing_scripts+=("$s")
  elif [ ! -x "$repo_root/$s" ]; then
    not_executable+=("$s")
  fi
done
if [ "${#missing_scripts[@]}" -eq 0 ]; then
  check PASS "required scripts" "all present"
else
  check FAIL "required scripts" "missing: ${missing_scripts[*]}" "re-run Phase 10/12 of setup"
fi
if [ "${#not_executable[@]}" -eq 0 ]; then
  check PASS "executable permissions" "all required scripts are +x"
else
  check FAIL "executable permissions" "${not_executable[*]}" "chmod +x ${not_executable[*]}"
fi

echo
echo "=== Summary: $PASS PASS, $WARN WARN, $FAIL FAIL ==="
[ "$FAIL" -eq 0 ]
