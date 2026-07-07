#!/usr/bin/env bash
# Read-only by default: detect exact Pi model/OS/arch/Python/storage/memory
# and print JSON inventory to stdout. Saving the local manifest requires the
# explicit --write-manifest option. Never modifies the Pi itself.
set -euo pipefail
# shellcheck source=scripts/common/lib.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../common/lib.sh"

ns_load_hardware_env
pi_alias="$NEUROSYNC_PI_HOST"
repo_root="$(ns_repo_root)"
manifest="$repo_root/hardware/manifests/raspberry-pi.json"
write_manifest=0

for arg in "$@"; do
  case "$arg" in
    --write-manifest) write_manifest=1 ;;
    *) ns_log_err "Unknown argument: $arg"; exit 2 ;;
  esac
done

ns_log_info "Checking reachability of $pi_alias ($NEUROSYNC_PI_HOSTNAME)..."
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$pi_alias" true 2>/dev/null; then
  ns_log_err "$pi_alias is not reachable via SSH. See docs/setup/manual-actions.md."
  exit 1
fi

ns_log_info "Collecting inventory from $pi_alias (read-only)..."
model="$(ssh -o BatchMode=yes "$pi_alias" 'cat /proc/device-tree/model 2>/dev/null | tr -d "\0"' || echo unknown)"
os_pretty="$(ssh -o BatchMode=yes "$pi_alias" '. /etc/os-release 2>/dev/null; echo "$PRETTY_NAME"' || echo unknown)"
arch="$(ssh -o BatchMode=yes "$pi_alias" 'uname -m' || echo unknown)"
python_version="$(ssh -o BatchMode=yes "$pi_alias" 'python3 --version 2>&1' || echo unknown)"
mem_kb="$(ssh -o BatchMode=yes "$pi_alias" "awk '/MemTotal/ {print \$2}' /proc/meminfo" || echo 0)"
storage_line="$(ssh -o BatchMode=yes "$pi_alias" "df -h / | tail -1" || echo unknown)"
detected_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

tmp_manifest=""
cleanup() {
  if [ -n "$tmp_manifest" ] && [ -f "$tmp_manifest" ]; then
    rm -f "$tmp_manifest"
  fi
}
trap cleanup EXIT

output_path="/dev/stdout"
if [ "$write_manifest" = "1" ]; then
  tmp_manifest="$(mktemp "$manifest.tmp.XXXXXX")"
  output_path="$tmp_manifest"
fi

python3 - "$model" "$os_pretty" "$arch" "$python_version" "$mem_kb" "$storage_line" "$detected_at" >"$output_path" <<'PYEOF'
import json
import sys

model, os_pretty, arch, python_version, mem_kb, storage_line, detected_at = sys.argv[1:8]

data = {
    "raspberry_pi": {
        "model": model.strip(),
        "os": os_pretty.strip(),
        "architecture": arch.strip(),
        "python_version": python_version.strip(),
        "memory_mb": round(int(mem_kb.strip() or 0) / 1024),
        "storage_root": storage_line.strip(),
        "detected_at": detected_at,
    }
}
json.dump(data, sys.stdout, indent=2)
sys.stdout.write("\n")
PYEOF

if [ "$write_manifest" = "1" ]; then
  mv "$tmp_manifest" "$manifest"
  tmp_manifest=""
  ns_log_info "Wrote $manifest"
  cat "$manifest"
fi
