#!/usr/bin/env bash
# Enable the PiFi DAC+ V2.0 / PCM5122 I2S overlay on Raspberry Pi OS.
# This edits /boot/firmware/config.txt and requires an explicit --confirm.
set -euo pipefail
# shellcheck source=../common/lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

CONFIRM_FLAG=0
CONFIG_PATH="/boot/firmware/config.txt"

usage() {
  cat <<'EOF'
Usage: scripts/pi/configure-pifi.sh --confirm [--config PATH]

Enables the HiFiBerry DAC overlay used by PCM5122-compatible boards:
  dtoverlay=hifiberry-dac

Also disables onboard analog audio:
  dtparam=audio=off

This script must be run on the Raspberry Pi and a reboot is required after
it changes /boot/firmware/config.txt.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --confirm)
      CONFIRM_FLAG=1
      ;;
    --config=*)
      CONFIG_PATH="${arg#--config=}"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      ns_log_err "Unknown argument: $arg"
      usage >&2
      exit 2
      ;;
  esac
done

ns_require_confirm "PiFi boot configuration"

if [ ! -f "$CONFIG_PATH" ]; then
  ns_log_err "boot config not found: $CONFIG_PATH"
  exit 1
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_path="${CONFIG_PATH}.bak.${timestamp}"
tmp_path="$(mktemp "${CONFIG_PATH}.tmp.XXXXXX")"

cleanup() {
  [ -f "$tmp_path" ] && rm -f "$tmp_path"
}
trap cleanup EXIT

ns_log_info "Backing up $CONFIG_PATH to $backup_path"
cp -p "$CONFIG_PATH" "$backup_path"

awk '
  BEGIN {
    saw_audio = 0
    saw_overlay = 0
  }
  /^[[:space:]]*dtparam=audio=/ {
    if (!saw_audio) {
      print "dtparam=audio=off"
      saw_audio = 1
    }
    next
  }
  /^[[:space:]]*dtoverlay=hifiberry-dac([[:space:]]|$)/ {
    if (!saw_overlay) {
      print "dtoverlay=hifiberry-dac"
      saw_overlay = 1
    }
    next
  }
  { print }
  END {
    if (!saw_audio) {
      print "dtparam=audio=off"
    }
    if (!saw_overlay) {
      print "dtoverlay=hifiberry-dac"
    }
  }
' "$CONFIG_PATH" >"$tmp_path"

if cmp -s "$CONFIG_PATH" "$tmp_path"; then
  ns_log_info "$CONFIG_PATH already contains the requested PiFi settings."
else
  cat "$tmp_path" >"$CONFIG_PATH"
  ns_log_info "Updated $CONFIG_PATH"
fi

ns_log_info "Assumption to confirm on the bench:"
ns_log_info "  PiFi DAC+ V2.0 is PCM5122-based and HiFiBerry-DAC-compatible."
ns_log_info "  The Raspberry Pi overlay used for this board is dtoverlay=hifiberry-dac."
ns_log_info "Next steps:"
ns_log_info "  1. Reboot the Raspberry Pi."
ns_log_info "  2. Run scripts/pi/verify-pifi.sh after reboot."
ns_log_info "  3. Generate WAVs with python -m neurosync.audio.test_tone and play them with aplay."
