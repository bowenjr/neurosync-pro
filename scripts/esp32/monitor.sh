#!/usr/bin/env bash
# Open the serial monitor. Never flashes.
set -euo pipefail
# shellcheck source=../common/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

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

port="$NEUROSYNC_ESP32_PORT"
if [ "$port" = "auto" ]; then
  port="$("$(dirname "${BASH_SOURCE[0]}")/detect.sh" --select)"
fi

ns_log_info "Opening monitor on $port (Ctrl+] to exit). This does not flash."
idf.py -C "$fw_dir" -p "$port" monitor
