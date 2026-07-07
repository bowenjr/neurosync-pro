#!/usr/bin/env bash
# One-time Pi bootstrap: verify it's actually a Raspberry Pi, install the
# minimal required packages, create the app directory, install uv.
# Requires --confirm. Does NOT touch /boot, audio config, install a
# desktop, or install Codex/Claude Code.
#
# Usage: scripts/pi/bootstrap.sh --confirm
set -euo pipefail
# shellcheck source=scripts/common/lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

# shellcheck disable=SC2034
CONFIRM_FLAG=0
for arg in "$@"; do
  case "$arg" in
    --confirm) CONFIRM_FLAG=1 ;;
    *) ns_log_err "Unknown argument: $arg"; exit 2 ;;
  esac
done
export CONFIRM_FLAG
ns_require_confirm "Bootstrapping the Raspberry Pi"

ns_load_hardware_env
pi_alias="$NEUROSYNC_PI_HOST"
pi_path="$NEUROSYNC_PI_PATH"

ns_log_info "Checking reachability of $pi_alias ($NEUROSYNC_PI_HOSTNAME)..."
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$pi_alias" true 2>/dev/null; then
  ns_log_err "$pi_alias is not reachable via SSH. See docs/setup/manual-actions.md."
  exit 1
fi

model="$(ssh -o BatchMode=yes "$pi_alias" 'cat /proc/device-tree/model 2>/dev/null | tr -d "\0"' || echo "")"
ns_log_info "Detected model string: ${model:-<none>}"
if [[ "$model" != *"Raspberry Pi"* ]]; then
  ns_log_err "Target does not identify as a Raspberry Pi (got: '${model:-empty}'). Refusing to bootstrap a non-Pi host."
  exit 1
fi

ns_log_info "Proceeding with bootstrap of: $model"

ssh -o BatchMode=yes "$pi_alias" bash -s -- "$pi_path" <<'REMOTE_SCRIPT'
set -euo pipefail
APP_DIR="$1"

echo "== Installing required packages (apt) =="
sudo apt-get update
sudo apt-get install -y python3 python3-venv python3-pip git curl rsync

echo "== Creating app directory: $APP_DIR =="
mkdir -p "$APP_DIR"

echo "== Installing uv (user-space) if missing =="
if ! command -v uv >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/uv" ]; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
else
  echo "uv already present"
fi

echo "== Bootstrap complete =="
REMOTE_SCRIPT

ns_log_info "Bootstrap commands finished. Writing inventory..."
"$(dirname "${BASH_SOURCE[0]}")/inventory.sh" --write-manifest
