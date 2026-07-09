#!/usr/bin/env bash
# Installs the system-level NeuroSync controller unit on the Pi.
# Requires --confirm. Does not start the service; use the explicit
# pi-controller-start target after reviewing the installed unit.
#
# Usage: scripts/pi/install-services.sh --confirm
set -euo pipefail
# shellcheck source=../common/lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

CONFIRM_FLAG=0
for arg in "$@"; do
  case "$arg" in
    --confirm) CONFIRM_FLAG=1 ;;
    *) ns_log_err "Unknown argument: $arg"; exit 2 ;;
  esac
done
if [ "$CONFIRM_FLAG" != "1" ]; then
  ns_require_confirm "Installing systemd units on the Raspberry Pi"
fi

ns_load_hardware_env
repo_root="$(ns_repo_root)"
pi_alias="$NEUROSYNC_PI_HOST"
unit="$repo_root/infra/pi/systemd/neurosync-controller.service"

if [ ! -f "$unit" ]; then
  ns_log_err "Missing controller unit: $unit"
  exit 1
fi

ns_log_info "Installing neurosync-controller.service on $pi_alias without starting it..."
ssh -o BatchMode=yes "$pi_alias" bash -s -- "$NEUROSYNC_PI_USER" <<'REMOTE_SCRIPT'
set -euo pipefail
user="$1"
sudo groupadd -f neurosync
sudo usermod -aG neurosync "$user"
if getent group dialout >/dev/null 2>&1; then
  sudo usermod -aG dialout "$user"
fi
REMOTE_SCRIPT

ssh -o BatchMode=yes "$pi_alias" 'sudo install -o root -g root -m 0644 /dev/stdin /etc/systemd/system/neurosync-controller.service' <"$unit"
ssh -o BatchMode=yes "$pi_alias" 'sudo systemctl daemon-reload'
ns_log_info "Installed neurosync-controller.service. It has not been enabled or started."
