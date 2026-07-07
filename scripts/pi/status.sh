#!/usr/bin/env bash
# Read-only: is the Pi reachable, and basic status if so. Never modifies
# anything on the Pi.
set -euo pipefail
# shellcheck source=../common/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

ns_load_hardware_env
pi_alias="$NEUROSYNC_PI_HOST"

ns_log_info "Checking reachability of $pi_alias ($NEUROSYNC_PI_HOSTNAME)..."
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$pi_alias" true 2>/dev/null; then
  ns_log_err "$pi_alias is not reachable via SSH (host down, not networked, or key not yet authorized)."
  exit 1
fi

ns_log_info "$pi_alias is reachable. Fetching status (read-only)..."
ssh -o BatchMode=yes -o ConnectTimeout=5 "$pi_alias" bash -s <<'REMOTE_SCRIPT'
  echo "Hostname:     $(hostname)"
  echo "Uptime:       $(uptime -p 2>/dev/null || uptime)"
  echo "Kernel:       $(uname -r)"
  echo "Load average: $(cut -d' ' -f1-3 /proc/loadavg)"
  echo "Disk (/):"
  df -h / | tail -1
  echo "Memory:"
  free -h | head -2
REMOTE_SCRIPT
