#!/usr/bin/env bash
# Parser-level checks for Makefile boolean control variables. Uses make -n
# only; no deploy, flash, SSH, or hardware command is executed.
set -euo pipefail

# shellcheck source=scripts/common/lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

repo_root="$(ns_repo_root)"

require_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    ns_log_err "$name: expected dry-run output to contain '$needle'"
    exit 1
  fi
}

require_not_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    ns_log_err "$name: dry-run output must not contain '$needle'"
    exit 1
  fi
}

require_success() {
  local _name="$1"
  shift
  local output
  output="$(make -C "$repo_root" -n "$@" 2>&1)"
  printf '%s\n' "$output"
}

require_failure() {
  local name="$1"
  shift
  local output
  if output="$(make -C "$repo_root" -n "$@" 2>&1)"; then
    ns_log_err "$name: expected make dry-run to fail"
    printf '%s\n' "$output" >&2
    exit 1
  fi
  printf '%s\n' "$output"
}

out="$(require_success "FORCE_DIRTY empty" esp32-flash CONFIRM=YES FORCE_DIRTY=)"
require_not_contains "FORCE_DIRTY empty" "$out" "--force-dirty"

out="$(require_success "FORCE_DIRTY 0" esp32-flash CONFIRM=YES FORCE_DIRTY=0)"
require_not_contains "FORCE_DIRTY 0" "$out" "--force-dirty"

out="$(require_success "FORCE_DIRTY NO" esp32-flash CONFIRM=YES FORCE_DIRTY=NO)"
require_not_contains "FORCE_DIRTY NO" "$out" "--force-dirty"

out="$(require_success "FORCE_DIRTY YES" esp32-flash CONFIRM=YES FORCE_DIRTY=YES)"
require_contains "FORCE_DIRTY YES" "$out" "--force-dirty"

out="$(require_failure "FORCE_DIRTY garbage" esp32-flash CONFIRM=YES FORCE_DIRTY=garbage)"
require_contains "FORCE_DIRTY garbage" "$out" "FORCE_DIRTY must be empty or one of"

out="$(require_success "RESTART 0" pi-deploy CONFIRM=YES RESTART=0)"
require_not_contains "RESTART 0" "$out" "--restart"

out="$(require_success "RESTART YES" pi-deploy CONFIRM=YES RESTART=YES)"
require_contains "RESTART YES" "$out" "--restart"

out="$(require_failure "CONFIRM NO" pi-deploy CONFIRM=NO)"
require_contains "CONFIRM NO" "$out" "pi-deploy requires affirmative CONFIRM"

out="$(require_success "CONFIRM YES" pi-deploy CONFIRM=YES)"
require_contains "CONFIRM YES" "$out" "scripts/pi/deploy.sh --confirm"

out="$(require_success "pi-inventory read-only" pi-inventory)"
require_contains "pi-inventory read-only" "$out" "scripts/pi/inventory.sh"
require_not_contains "pi-inventory read-only" "$out" "--write-manifest"
require_not_contains "pi-inventory read-only" "$out" "hardware/manifests/raspberry-pi.json"

out="$(require_failure "pi-inventory-save no confirm" pi-inventory-save)"
require_contains "pi-inventory-save no confirm" "$out" "pi-inventory-save requires affirmative CONFIRM"

ns_log_info "Makefile boolean dry-run checks passed."
