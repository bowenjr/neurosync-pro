#!/usr/bin/env bash
# Read-only PiFi ALSA verification helper. Does not play audio.
set -euo pipefail

echo "== Kernel and available HiFiBerry overlays =="
uname -r
ls -1 /boot/firmware/overlays/hifiberry-dacplus*.dtbo
echo

echo "== ALSA cards =="
aplay -l
echo

echo "== PCM5122 / HiFiBerry-like cards =="
if ! aplay -l | grep -Ei 'pcm5122|hifiberry|sndrpihifiberry|snd_rpi_hifiberry|dacplus|dac'; then
  echo "No obvious PCM5122/HiFiBerry DAC card found in aplay -l output." >&2
  exit 1
fi
echo

echo "== Named ALSA PCMs =="
aplay -L | sed -n '1,80p'
echo

echo "== PCM512x / clock / reset kernel messages =="
if dmesg | grep -Ei 'pcm512|hifiberry|sclk|bclk|reset|probe'; then
  if dmesg | grep -Ei 'pcm512|hifiberry|sclk|bclk|reset|probe' | grep -Eiq 'error|fail|timeout|unable|cannot'; then
    echo "Kernel log contains possible PiFi probe/reset/SCLK errors." >&2
    exit 1
  fi
else
  echo "No PCM512x/HiFiBerry-related dmesg lines found; review full dmesg if ALSA looks wrong."
fi
echo

echo "Suggested checks:"
echo "  aplay -l | awk '/pcm5122|HiFiBerry|DAC|sndrpihifiberry|snd_rpi_hifiberry/ {print}' IGNORECASE=1"
echo "  aplay -L | grep -Ei 'sndrpihifiberry|dacplus|hifiberry'"
echo "  aplay -D plughw:CARD=sndrpihifiberry,DEV=0 --dump-hw-params /tmp/neurosync-pifi-left.wav"
