#!/usr/bin/env bash
# Flash the built ESP32 firmware image. NEVER erases flash. Requires
# --confirm; requires --force-dirty as a second explicit confirmation if the
# repository has uncommitted changes.
#
# Usage: scripts/esp32/flash.sh --confirm [--force-dirty]
set -euo pipefail
# shellcheck source=../common/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

CONFIRM_FLAG=0
FORCE_DIRTY=0
for arg in "$@"; do
  case "$arg" in
    --confirm) CONFIRM_FLAG=1 ;;
    --force-dirty) FORCE_DIRTY=1 ;;
    *) ns_log_err "Unknown argument: $arg"; exit 2 ;;
  esac
done

ns_require_confirm "Flashing the ESP32"

ns_load_hardware_env
repo_root="$(ns_repo_root)"
fw_dir="$repo_root/firmware/esp32"

idf_path="$NEUROSYNC_ESP_IDF_PATH"
if [ "$idf_path" = "auto" ]; then
  idf_path="$HOME/esp/esp-idf-current"
fi
if [ ! -f "$idf_path/export.sh" ]; then
  ns_log_err "ESP-IDF not found at $idf_path (export.sh missing). Run Phase 9 setup first."
  exit 1
fi
# shellcheck source=/dev/null
source "$idf_path/export.sh" >/dev/null

target="$NEUROSYNC_ESP32_TARGET"
if [ "$target" != "esp32" ]; then
  ns_log_err "NEUROSYNC_ESP32_TARGET is '$target', not 'esp32'. Refusing to flash an unexpected target."
  exit 1
fi

port="$NEUROSYNC_ESP32_PORT"
if [ "$port" = "auto" ]; then
  port="$("$(dirname "${BASH_SOURCE[0]}")/detect.sh" --select)"
fi

commit="$(ns_git_commit)"

echo "=== NeuroSync ESP32 flash pre-flight ==="
echo "Git commit:     $commit"
echo "ESP-IDF:        $(idf.py --version)"
echo "Target:         $target"
echo "Serial port:    $port"
echo "Firmware dir:   $fw_dir"
echo "========================================="

if ns_git_is_dirty; then
  if [ "$FORCE_DIRTY" != "1" ]; then
    ns_log_err "Repository has uncommitted changes. Flashing an uncommitted build is not traceable to a commit."
    ns_log_err "Commit your changes, or re-run with --confirm --force-dirty to flash anyway."
    git -C "$repo_root" status --short
    exit 1
  fi
  ns_log_warn "Repository is dirty; proceeding because --force-dirty was given explicitly."
fi

ns_log_info "Flashing (this writes the built application image; it does NOT erase flash)."
idf.py -C "$fw_dir" -p "$port" flash
