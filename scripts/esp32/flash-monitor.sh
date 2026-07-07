#!/usr/bin/env bash
# Flash then open the monitor. Same --confirm/--force-dirty gating as
# flash.sh — this wrapper does not weaken it.
set -euo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"

"$here/flash.sh" "$@"
"$here/monitor.sh"
