#!/usr/bin/env bash
# Shared helpers sourced by scripts/{esp32,pi,doctor}/*.sh. Not meant to be
# executed directly.
set -euo pipefail

ns_log_info()  { printf '[INFO] %s\n' "$*"; }
ns_log_warn()  { printf '[WARN] %s\n' "$*" >&2; }
ns_log_err()   { printf '[ERROR] %s\n' "$*" >&2; }

# Repo root = two levels up from scripts/common/.
ns_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

# Loads ~/.config/neurosync/hardware.env if present, falling back to
# config/hardware.env.example values already exported as safe defaults by
# the caller. Never overwrites already-exported values (process env wins).
ns_load_hardware_env() {
  local local_env="${XDG_CONFIG_HOME:-$HOME/.config}/neurosync/hardware.env"
  if [ -f "$local_env" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$local_env"
    set +a
  fi
  : "${NEUROSYNC_PI_HOST:=neurosync-pi}"
  : "${NEUROSYNC_PI_HOSTNAME:=neurosync-pi.local}"
  : "${NEUROSYNC_PI_USER:=bowen}"
  : "${NEUROSYNC_PI_PATH:=/home/bowen/apps/neurosync-pro}"
  : "${NEUROSYNC_ESP32_TARGET:=esp32}"
  : "${NEUROSYNC_ESP32_PORT:=auto}"
  : "${NEUROSYNC_ESP_IDF_PATH:=auto}"
}

# Require that CONFIRM_FLAG=1 was set by the caller's arg parsing before
# proceeding with an irreversible/hardware-affecting action.
ns_require_confirm() {
  local what="$1"
  if [ "${CONFIRM_FLAG:-0}" != "1" ]; then
    ns_log_err "$what requires --confirm. Refusing to proceed without it."
    exit 2
  fi
}

ns_git_commit() {
  git -C "$(ns_repo_root)" rev-parse --short HEAD 2>/dev/null || echo "unknown (no commits yet)"
}

ns_git_is_dirty() {
  [ -n "$(git -C "$(ns_repo_root)" status --porcelain 2>/dev/null || true)" ]
}

# Resolve the exact esp-idf install directory (not the "current" symlink),
# for printing in flash/build logs. Falls back to "unknown".
ns_idf_version_string() {
  if command -v idf.py >/dev/null 2>&1; then
    idf.py --version 2>/dev/null || echo "unknown"
  else
    echo "idf.py not on PATH (source export.sh or use neurosync-idf)"
  fi
}
