#!/usr/bin/env bash
# Deploy the committed repository state to the Raspberry Pi via rsync
# (never --delete). Requires --confirm. Does not restart services unless
# --restart is separately passed.
#
# Usage: scripts/pi/deploy.sh --confirm [--restart]
set -euo pipefail
# shellcheck source=../common/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

CONFIRM_FLAG=0
RESTART_FLAG=0
for arg in "$@"; do
  case "$arg" in
    --confirm) CONFIRM_FLAG=1 ;;
    --restart) RESTART_FLAG=1 ;;
    *) ns_log_err "Unknown argument: $arg"; exit 2 ;;
  esac
done
ns_require_confirm "Deploying to the Raspberry Pi"

ns_load_hardware_env
pi_alias="$NEUROSYNC_PI_HOST"
pi_path="$NEUROSYNC_PI_PATH"
repo_root="$(ns_repo_root)"

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
echo "============================"

if ns_git_is_dirty; then
  ns_log_warn "Repository has uncommitted changes; deploying working tree state (not just the commit)."
  git -C "$repo_root" status --short
fi

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
  --exclude '!config/*.env.example' \
  --exclude '.claude/' \
  --exclude '.codex/' \
  "$repo_root"/ "$pi_alias:$pi_path/"

if [ -f "$repo_root/uv.lock" ]; then
  ns_log_info "Running 'uv sync --locked' on $pi_alias..."
  ssh -o BatchMode=yes "$pi_alias" "cd '$pi_path' && (command -v uv >/dev/null 2>&1 || export PATH=\"\$HOME/.local/bin:\$PATH\"); cd '$pi_path' && uv sync --locked"
fi

ns_log_info "Running remote unit tests..."
ssh -o BatchMode=yes "$pi_alias" "cd '$pi_path' && export PATH=\"\$HOME/.local/bin:\$PATH\" && uv run pytest tests/unit -q"

if [ "$RESTART_FLAG" = 1 ]; then
  ns_log_warn "Restart requested but install-services.sh has not been run in this setup; no systemd units exist yet to restart."
else
  ns_log_info "Deploy complete. Services were not restarted (pass --restart once systemd units exist)."
fi
