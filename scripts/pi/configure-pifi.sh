#!/usr/bin/env bash
# Enable the PiFi DAC+ V2.0 / PCM5122 I2S overlay on Raspberry Pi OS.
# This edits /boot/firmware/config.txt and requires --confirm unless --dry-run is used.
set -euo pipefail
# shellcheck source=../common/lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

# shellcheck disable=SC2034  # consumed by ns_require_confirm from scripts/common/lib.sh
CONFIRM_FLAG=0
CONFIG_PATH="/boot/firmware/config.txt"
DRY_RUN=0
OVERLAY_DIR="/boot/firmware/overlays"
DEFAULT_OVERLAY="hifiberry-dacplus-std"
FALLBACK_OVERLAY="hifiberry-dacplus"
OVERLAY_NAME="$DEFAULT_OVERLAY"

usage() {
  cat <<'EOF'
Usage: scripts/pi/configure-pifi.sh [--dry-run] --confirm [--config PATH] [--overlay NAME]

Enables a HiFiBerry DAC+ overlay used by PCM5122-compatible DAC+ boards.
For the verified PiFi DAC+ V2.0 target on Raspberry Pi OS Trixie
(kernel 6.18.34+rpt-rpi-v8), the default target is:
  dtoverlay=hifiberry-dacplus-std

For older kernels, use the documented fallback if the std overlay is absent:
  dtoverlay=hifiberry-dacplus

Also disables onboard analog audio:
  dtparam=audio=off

And explicitly enables I2S:
  dtparam=i2s=on

Before editing boot config, run and review:
  uname -r
  ls -1 /boot/firmware/overlays/hifiberry-dacplus*.dtbo

Use --dry-run first to print the proposed config.txt to stdout without
writing anything. Use --confirm only after reviewing the dry-run output.

This script must be run on the Raspberry Pi and a reboot is required after
it changes /boot/firmware/config.txt.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --confirm)
      # shellcheck disable=SC2034  # consumed by ns_require_confirm from scripts/common/lib.sh
      CONFIRM_FLAG=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --config=*)
      CONFIG_PATH="${arg#--config=}"
      ;;
    --overlay=*)
      OVERLAY_NAME="${arg#--overlay=}"
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

if [ "$DRY_RUN" != "1" ]; then
  ns_require_confirm "PiFi boot configuration"
fi

case "$OVERLAY_NAME" in
  hifiberry-dacplus-std|hifiberry-dacplus)
    ;;
  *)
    ns_log_err "Unsupported PiFi overlay override: $OVERLAY_NAME"
    ns_log_err "Use hifiberry-dacplus-std or hifiberry-dacplus after checking available .dtbo files."
    exit 2
    ;;
esac

if [ ! -f "$CONFIG_PATH" ]; then
  ns_log_err "boot config not found: $CONFIG_PATH"
  exit 1
fi

if [ "$DRY_RUN" != "1" ] && [ ! -f "${OVERLAY_DIR}/${OVERLAY_NAME}.dtbo" ]; then
  ns_log_err "Requested overlay is absent: ${OVERLAY_DIR}/${OVERLAY_NAME}.dtbo"
  ns_log_err "Run: uname -r"
  ns_log_err "Run: ls -1 ${OVERLAY_DIR}/hifiberry-dacplus*.dtbo"
  ns_log_err "Use --overlay=${FALLBACK_OVERLAY} only if that fallback .dtbo is verified present."
  exit 1
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_path="${CONFIG_PATH}.bak.${timestamp}"
tmp_path="$(mktemp "${CONFIG_PATH}.tmp.XXXXXX")"

cleanup() {
  [ -f "$tmp_path" ] && rm -f "$tmp_path"
}
trap cleanup EXIT

transform_config() {
  local input_path="$1"
  awk -v overlay="$OVERLAY_NAME" '
  BEGIN {
    saw_audio = 0
    saw_i2s = 0
  }
  /^[[:space:]]*#?[[:space:]]*dtparam=audio=/ {
    if (!saw_audio) {
      print "dtparam=audio=off"
      saw_audio = 1
    }
    next
  }
  /^[[:space:]]*#?[[:space:]]*dtparam=i2s=/ {
    if (!saw_i2s) {
      print "dtparam=i2s=on"
      saw_i2s = 1
    }
    next
  }
  /^[[:space:]]*#?[[:space:]]*dtoverlay=hifiberry-/ {
    next
  }
  { print }
  END {
    if (!saw_audio) {
      print "dtparam=audio=off"
    }
    if (!saw_i2s) {
      print "dtparam=i2s=on"
    }
    print "dtoverlay=" overlay
  }
  ' "$input_path"
}

transform_config "$CONFIG_PATH" >"$tmp_path"

if [ "$DRY_RUN" = "1" ]; then
  cat "$tmp_path"
  exit 0
fi

ns_log_info "Selected overlay: dtoverlay=${OVERLAY_NAME}"
ns_log_info "Backing up $CONFIG_PATH to $backup_path"
cp -p "$CONFIG_PATH" "$backup_path"

if cmp -s "$CONFIG_PATH" "$tmp_path"; then
  ns_log_info "$CONFIG_PATH already contains the requested PiFi settings."
else
  cat "$tmp_path" >"$CONFIG_PATH"
  ns_log_info "Updated $CONFIG_PATH"
fi

ns_log_info "Assumption to confirm on the bench:"
ns_log_info "  PiFi DAC+ V2.0 is PCM5122-based and HiFiBerry-DAC-compatible."
ns_log_info "  The selected Raspberry Pi overlay is dtoverlay=${OVERLAY_NAME}."
ns_log_info "  hifiberry-dacplus-std is confirmed present on kernel 6.18.34+rpt-rpi-v8;"
ns_log_info "  hifiberry-dacplus is the fallback when the std .dtbo is absent."
ns_log_info "Next steps:"
ns_log_info "  1. Reboot the Raspberry Pi."
ns_log_info "  2. Run scripts/pi/verify-pifi.sh after reboot."
ns_log_info "  3. Generate WAVs with .venv/bin/python -m neurosync.audio.test_tone and play them with aplay."
