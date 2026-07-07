#!/usr/bin/env bash
# Deploy the committed repository state to the Raspberry Pi via rsync
# (never --delete). Requires --confirm. Does not restart services unless
# --restart is separately passed.
#
# Usage: scripts/pi/deploy.sh --confirm [--restart] [--force-dirty]
set -euo pipefail
# shellcheck source=../common/lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

CONFIRM_FLAG=0
RESTART_FLAG=0
FORCE_DIRTY=0
for arg in "$@"; do
  case "$arg" in
    --confirm) CONFIRM_FLAG=1 ;;
    --restart) RESTART_FLAG=1 ;;
    --force-dirty) FORCE_DIRTY=1 ;;
    *) ns_log_err "Unknown argument: $arg"; exit 2 ;;
  esac
done
if [ "$CONFIRM_FLAG" != "1" ]; then
  ns_require_confirm "Deploying to the Raspberry Pi"
fi

ns_load_hardware_env
pi_alias="$NEUROSYNC_PI_HOST"
pi_path="$NEUROSYNC_PI_PATH"
remote_uv="/home/bowen/.local/bin/uv"
repo_root="$(ns_repo_root)"

if ns_git_is_dirty; then
  if [ "$FORCE_DIRTY" != "1" ]; then
    ns_log_err "Repository has uncommitted changes. Refusing to deploy dirty working tree."
    ns_log_err "Use FORCE_DIRTY=YES with make pi-deploy only when this is intentional."
    git -C "$repo_root" status --short
    exit 1
  fi
  ns_log_warn "Repository has uncommitted changes; --force-dirty permits deploying working tree state."
  git -C "$repo_root" status --short
fi

ns_log_info "Checking reachability of $pi_alias ($NEUROSYNC_PI_HOSTNAME)..."
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$pi_alias" true 2>/dev/null; then
  ns_log_err "$pi_alias is not reachable via SSH. See docs/setup/manual-actions.md."
  exit 1
fi

commit="$(ns_git_commit)"
echo "=== NeuroSync Pi deploy ==="
echo "Git commit:  $commit"
echo "Target:      $pi_alias:$pi_path"
echo "Restart:     $([ "$RESTART_FLAG" = 1 ] && echo yes || echo no)"
echo "Dirty tree:  $([ "$FORCE_DIRTY" = 1 ] && echo allowed || echo refused)"
echo "============================"

ns_log_info "rsync (no --delete) to $pi_alias:$pi_path"
rsync -avz --no-perms \
  --exclude '.git/' \
  --exclude '.venv/' \
  --exclude '__pycache__/' \
  --exclude '.mypy_cache/' \
  --exclude '.pytest_cache/' \
  --exclude '.ruff_cache/' \
  --exclude 'firmware/esp32/build/' \
  --exclude 'measurements/raw/' \
  --exclude '.env' \
  --exclude '*.env' \
  --exclude '.claude/' \
  --exclude '.codex/' \
  "$repo_root"/ "$pi_alias:$pi_path/"

if [ -f "$repo_root/uv.lock" ]; then
  ns_log_info "Running 'uv sync --locked' on $pi_alias..."
  ssh -o BatchMode=yes "$pi_alias" bash -s -- "$pi_path" "$remote_uv" <<'REMOTE_SCRIPT'
set -euo pipefail
cd "$1"
"$2" sync --locked
REMOTE_SCRIPT
fi

ns_log_info "Running remote unit tests..."
ssh -o BatchMode=yes "$pi_alias" bash -s -- "$pi_path" "$remote_uv" <<'REMOTE_SCRIPT'
set -euo pipefail
cd "$1"
"$2" run pytest tests/unit -q
REMOTE_SCRIPT

if [ "$RESTART_FLAG" = 1 ]; then
  ns_log_warn "Restart requested but install-services.sh has not been run in this setup; no systemd units exist yet to restart."
else
  ns_log_info "Deploy complete. Services were not restarted (pass --restart once systemd units exist)."
fi
