#!/usr/bin/env bash
# Open an interactive SSH shell on the Pi, cd'd into the app directory.
set -euo pipefail
# shellcheck source=../common/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

ns_load_hardware_env
pi_alias="$NEUROSYNC_PI_HOST"
pi_path="$NEUROSYNC_PI_PATH"

exec ssh -t "$pi_alias" "cd '$pi_path' && exec \$SHELL -l"
