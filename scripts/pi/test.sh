#!/usr/bin/env bash
# Run the unit test suite on the Pi against whatever is currently deployed
# there. Read-only with respect to the Pi's files (does not deploy first —
# run deploy.sh if you want to test the latest local state).
set -euo pipefail
# shellcheck source=../common/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

ns_load_hardware_env
pi_alias="$NEUROSYNC_PI_HOST"
pi_path="$NEUROSYNC_PI_PATH"

ns_log_info "Checking reachability of $pi_alias ($NEUROSYNC_PI_HOSTNAME)..."
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$pi_alias" true 2>/dev/null; then
  ns_log_err "$pi_alias is not reachable via SSH. See docs/setup/manual-actions.md."
  exit 1
fi

ssh -o BatchMode=yes "$pi_alias" "cd '$pi_path' && export PATH=\"\$HOME/.local/bin:\$PATH\" && uv run pytest tests/unit -q"
