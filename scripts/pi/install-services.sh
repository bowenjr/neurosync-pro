#!/usr/bin/env bash
# Installs the systemd --user unit(s) under infra/pi/systemd/ onto the Pi.
#
# NOT run during initial setup. Refuses to run until a real application
# entry point (`neurosync-supervisor`) exists in the deployed pyproject.toml
# — installing a unit that immediately crash-loops is worse than not
# installing one. Requires --confirm.
#
# Usage: scripts/pi/install-services.sh --confirm
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
ns_require_confirm "Installing systemd units on the Raspberry Pi"

ns_load_hardware_env
repo_root="$(ns_repo_root)"
pi_alias="$NEUROSYNC_PI_HOST"
pi_path="$NEUROSYNC_PI_PATH"

if ! grep -q 'neurosync-supervisor' "$repo_root/pyproject.toml" 2>/dev/null; then
  ns_log_err "No 'neurosync-supervisor' entry point in pyproject.toml yet. Refusing to install a service for code that doesn't exist."
  ns_log_err "This is expected at initial-setup time — install-services.sh is intentionally not run during Phase 12."
  exit 1
fi

unit_dir="$repo_root/infra/pi/systemd"
ns_log_info "Installing unit templates from $unit_dir to $pi_alias..."
ssh -o BatchMode=yes "$pi_alias" 'mkdir -p ~/.config/systemd/user'
for template in "$unit_dir"/*.service.template; do
  name="$(basename "$template" .template)"
  sed "s#__NEUROSYNC_PI_PATH__#$pi_path#g" "$template" | \
    ssh -o BatchMode=yes "$pi_alias" "cat > ~/.config/systemd/user/$name"
  ssh -o BatchMode=yes "$pi_alias" "systemctl --user daemon-reload && systemctl --user enable --now $name"
  ns_log_info "Installed and started $name"
done
