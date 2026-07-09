#!/usr/bin/env bash
# Read-only PiFi ALSA verification helper. Does not play audio.
set -euo pipefail

echo "== ALSA cards =="
aplay -l
echo

echo "== PCM5122 / HiFiBerry-like cards =="
if ! aplay -l | grep -Ei 'pcm5122|hifiberry|snd_rpi_hifiberry_dac|dac'; then
  echo "No obvious PCM5122/HiFiBerry DAC card found in aplay -l output." >&2
  exit 1
fi
echo

echo "== Default PCM =="
aplay -L | sed -n '1,80p'
echo

echo "Suggested card extraction:"
echo "  aplay -l | awk '/pcm5122|HiFiBerry|DAC|snd_rpi_hifiberry_dac/ {print}' IGNORECASE=1"
echo
echo "Confirm the default by running:"
echo "  aplay -D default --dump-hw-params /tmp/neurosync-pifi-left.wav"
echo "or play explicitly through the detected card:"
echo "  aplay -D plughw:<CARD>,0 /tmp/neurosync-pifi-left.wav"
