#!/usr/bin/env bash
# Enumerate serial devices that could be the ESP32. Read-only: never opens,
# writes to, or configures a port.
#
# Usage:
#   scripts/esp32/detect.sh            # list all candidates, human-readable
#   scripts/esp32/detect.sh --select   # print exactly one device path, or
#                                       # exit non-zero if 0 or >1 candidates
set -euo pipefail
# shellcheck source=../common/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

mode="list"
if [ "${1:-}" = "--select" ]; then
  mode="select"
fi

shopt -s nullglob
devices=(/dev/ttyUSB* /dev/ttyACM*)
shopt -u nullglob

if [ "${#devices[@]}" -eq 0 ]; then
  if [ "$mode" = "select" ]; then
    ns_log_err "No candidate serial devices found (/dev/ttyUSB*, /dev/ttyACM*)."
    exit 1
  fi
  echo "No candidate serial devices found (/dev/ttyUSB*, /dev/ttyACM*)."
  exit 0
fi

describe() {
  local dev="$1" vid="?" pid="?" serial="?" manuf="?"
  if command -v udevadm >/dev/null 2>&1; then
    local info
    info="$(udevadm info --query=property --name="$dev" 2>/dev/null || true)"
    vid="$(printf '%s\n' "$info" | sed -n 's/^ID_VENDOR_ID=//p')"
    pid="$(printf '%s\n' "$info" | sed -n 's/^ID_MODEL_ID=//p')"
    serial="$(printf '%s\n' "$info" | sed -n 's/^ID_SERIAL_SHORT=//p')"
    manuf="$(printf '%s\n' "$info" | sed -n 's/^ID_VENDOR=//p')"
  fi
  printf '%s\tVID=%s\tPID=%s\tSERIAL=%s\tMANUFACTURER=%s\n' \
    "$dev" "${vid:-?}" "${pid:-?}" "${serial:-?}" "${manuf:-?}"
}

if [ "$mode" = "select" ]; then
  if [ "${#devices[@]}" -gt 1 ]; then
    ns_log_err "Multiple candidate devices found; refusing to guess. Set NEUROSYNC_ESP32_PORT explicitly:"
    for d in "${devices[@]}"; do describe "$d" >&2; done
    exit 1
  fi
  echo "${devices[0]}"
  exit 0
fi

echo "Candidate ESP32 serial devices (informational only — no port is opened):"
for d in "${devices[@]}"; do
  describe "$d"
done
