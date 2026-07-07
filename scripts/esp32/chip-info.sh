#!/usr/bin/env bash
# Read-only chip identification (chip model/revision/MAC). Never writes to
# flash.
set -euo pipefail
# shellcheck source=../common/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

ns_load_hardware_env

idf_path="$NEUROSYNC_ESP_IDF_PATH"
if [ "$idf_path" = "auto" ]; then
  idf_path="$HOME/esp/esp-idf-current"
fi
if [ -f "$idf_path/export.sh" ]; then
  # shellcheck source=/dev/null
  source "$idf_path/export.sh" >/dev/null
fi

if ! command -v esptool.py >/dev/null 2>&1; then
  ns_log_err "esptool.py not on PATH. Run scripts/esp32/build.sh once first (sources ESP-IDF env), or Phase 9 setup."
  exit 1
fi

port="$NEUROSYNC_ESP32_PORT"
if [ "$port" = "auto" ]; then
  port="$("$(dirname "${BASH_SOURCE[0]}")/detect.sh" --select)"
fi

ns_log_info "Reading chip info from $port (read-only)"
esptool.py --port "$port" chip_id
