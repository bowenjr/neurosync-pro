#!/usr/bin/env bash
# Read-only: tail logs on the Pi. Falls back to the app log directory if no
# systemd unit is installed yet (install-services.sh has not run in this
# setup).
#
# Usage: scripts/pi/logs.sh [lines]
set -euo pipefail
# shellcheck source=../common/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

ns_load_hardware_env
pi_alias="$NEUROSYNC_PI_HOST"
pi_path="$NEUROSYNC_PI_PATH"
lines="${1:-100}"

ns_log_info "Checking reachability of $pi_alias ($NEUROSYNC_PI_HOSTNAME)..."
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$pi_alias" true 2>/dev/null; then
  ns_log_err "$pi_alias is not reachable via SSH. See docs/setup/manual-actions.md."
  exit 1
fi

ssh -o BatchMode=yes "$pi_alias" bash -s -- "$pi_path" "$lines" <<'REMOTE_SCRIPT'
set -euo pipefail
APP_DIR="$1"
LINES="$2"

if systemctl --user list-units --no-legend 'neurosync-*' 2>/dev/null | grep -q neurosync; then
  journalctl --user -u 'neurosync-*' -n "$LINES" --no-pager
elif [ -d "$APP_DIR/data/logs" ]; then
  find "$APP_DIR/data/logs" -type f -name '*.log' -exec tail -n "$LINES" {} +
else
  echo "No systemd units and no $APP_DIR/data/logs directory found yet."
fi
REMOTE_SCRIPT
