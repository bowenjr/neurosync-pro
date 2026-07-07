#!/usr/bin/env bash
# Read-only Raspberry Pi deployment target verification. Never writes files,
# installs packages, syncs code, or restarts services.
set -euo pipefail
# shellcheck source=../common/lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

ns_load_hardware_env
pi_alias="$NEUROSYNC_PI_HOST"
pi_path="$NEUROSYNC_PI_PATH"
remote_uv="/home/bowen/.local/bin/uv"

ns_log_info "Checking SSH connectivity to $pi_alias ($NEUROSYNC_PI_HOSTNAME)..."
ssh -o BatchMode=yes -o ConnectTimeout=5 "$pi_alias" true

ns_log_info "Verifying Raspberry Pi target (read-only)..."
ssh -o BatchMode=yes -o ConnectTimeout=5 "$pi_alias" bash -s -- "$pi_path" "$remote_uv" <<'REMOTE_SCRIPT'
set -euo pipefail
APP_DIR="$1"
UV_BIN="$2"

echo "Hostname:          $(hostname)"
echo "Model:             $(tr -d '\0' </proc/device-tree/model 2>/dev/null || echo unknown)"

arch="$(uname -m)"
echo "Architecture:      $arch"
if [ "$arch" != "aarch64" ]; then
  echo "ERROR: expected aarch64 architecture" >&2
  exit 1
fi

bits="$(getconf LONG_BIT)"
echo "Userspace bits:    $bits"
if [ "$bits" != "64" ]; then
  echo "ERROR: expected 64-bit userspace" >&2
  exit 1
fi

echo "Python:            $(python3 --version 2>&1)"
echo "uv:                $("${UV_BIN}" --version 2>&1)"

if [ -d "$APP_DIR" ]; then
  echo "App directory:     $APP_DIR (present)"
else
  echo "ERROR: app directory missing: $APP_DIR" >&2
  exit 1
fi

echo "Disk (/):"
df -h /
echo "Memory:"
free -h
REMOTE_SCRIPT
