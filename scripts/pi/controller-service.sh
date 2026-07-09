#!/usr/bin/env bash
# Manage the system-level NeuroSync controller service on the Pi. Mutating
# actions require --confirm; status/logs/test are read-only.
set -euo pipefail
# shellcheck source=../common/lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

CONFIRM_FLAG=0
ACTION=""

for arg in "$@"; do
  case "$arg" in
    --confirm) CONFIRM_FLAG=1 ;;
    install|start|stop|restart|status|logs|test) ACTION="$arg" ;;
    *) ns_log_err "Unknown argument: $arg"; exit 2 ;;
  esac
done

if [ -z "$ACTION" ]; then
  ns_log_err "Usage: scripts/pi/controller-service.sh [--confirm] install|start|stop|restart|status|logs|test"
  exit 2
fi

case "$ACTION" in
  install|start|stop|restart)
    if [ "$CONFIRM_FLAG" != "1" ]; then
      ns_require_confirm "Controller service $ACTION on the Raspberry Pi"
    fi
    ;;
esac

ns_load_hardware_env
pi_alias="$NEUROSYNC_PI_HOST"
pi_path="$NEUROSYNC_PI_PATH"
unit="neurosync-controller.service"

case "$ACTION" in
  install)
    "$(dirname "${BASH_SOURCE[0]}")/install-services.sh" --confirm
    ;;
  start)
    ssh -o BatchMode=yes "$pi_alias" "sudo systemctl start $unit"
    ;;
  stop)
    ssh -o BatchMode=yes "$pi_alias" "sudo systemctl stop $unit"
    ;;
  restart)
    ssh -o BatchMode=yes "$pi_alias" "sudo systemctl restart $unit"
    ;;
  status)
    ssh -o BatchMode=yes "$pi_alias" "systemctl status $unit --no-pager"
    ;;
  logs)
    ssh -o BatchMode=yes "$pi_alias" "journalctl -u $unit -n 100 --no-pager"
    ;;
  test)
    ssh -o BatchMode=yes "$pi_alias" "cd '$pi_path' && .venv/bin/python -m neurosync.control.cli daemon-status"
    ;;
esac
