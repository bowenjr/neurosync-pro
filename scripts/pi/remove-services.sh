#!/usr/bin/env bash
# Stops and removes the systemd --user unit(s) this project installed on
# the Pi. Requires --confirm.
#
# Usage: scripts/pi/remove-services.sh --confirm
set -euo pipefail
# shellcheck source=../common/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

CONFIRM_FLAG=0
for arg in "$@"; do
  case "$arg" in
    --confirm) CONFIRM_FLAG=1 ;;
    *) ns_log_err "Unknown argument: $arg"; exit 2 ;;
  esac
done
ns_require_confirm "Removing systemd units from the Raspberry Pi"

ns_load_hardware_env
repo_root="$(ns_repo_root)"
pi_alias="$NEUROSYNC_PI_HOST"
unit_dir="$repo_root/infra/pi/systemd"

for template in "$unit_dir"/*.service.template; do
  name="$(basename "$template" .template)"
  ns_log_info "Stopping and removing $name on $pi_alias..."
  ssh -o BatchMode=yes "$pi_alias" "systemctl --user disable --now $name 2>/dev/null || true; rm -f ~/.config/systemd/user/$name"
done
ssh -o BatchMode=yes "$pi_alias" 'systemctl --user daemon-reload'
ns_log_info "Done."
