# PiFi DAC+ Phase 1 audio verification

Phase 1 verifies that the PiFi DAC+ V2.0 produces correct stereo
line-level audio from the Raspberry Pi 3 target. This is a bench-only
procedure; do not connect biological loads.

Safety note: all PiFi outputs are line-level outputs into a 10 kOhm
high-impedance measurement load. Do not connect speakers or low-impedance
headphones directly to the PiFi outputs.

## Hardware assumption

The PiFi DAC+ V2.0 is assumed to be PCM5122-based and compatible with the
HiFiBerry DAC overlay. The Raspberry Pi boot overlay used here is:

```ini
dtoverlay=hifiberry-dac
```

The human running the bench test must confirm this assumption against the
installed board label or vendor documentation before enabling the overlay.

## 1. Mount the HAT

1. Power down the Raspberry Pi 3.
2. Mount the PiFi DAC+ V2.0 on the 40-pin GPIO header.
3. Connect the left and right RCA outputs only to a 10 kOhm high-impedance
   measurement input, oscilloscope input, audio analyzer, or line-level
   dummy load.
4. Power the Raspberry Pi back on.

## 2. Enable the overlay

On the Raspberry Pi, from the checked-out repository:

```bash
scripts/pi/configure-pifi.sh --confirm
sudo reboot
```

The script backs up `/boot/firmware/config.txt`, enables
`dtoverlay=hifiberry-dac`, and sets `dtparam=audio=off` so onboard analog
audio does not confuse ALSA card ordering. The reboot is required before
ALSA will enumerate the I2S DAC.

## 3. Confirm ALSA enumeration after reboot

```bash
aplay -l
scripts/pi/verify-pifi.sh
```

Expected result: `aplay -l` lists a PCM5122 / HiFiBerry-DAC-compatible
card. Identify the card number and device number:

```bash
aplay -l | awk '/pcm5122|HiFiBerry|DAC|snd_rpi_hifiberry_dac/ {print}' IGNORECASE=1
```

Confirm the default PCM path:

```bash
aplay -L | sed -n '1,80p'
aplay -D default --dump-hw-params /tmp/neurosync-pifi-left.wav
```

If `default` is not the PiFi card, play explicitly through the detected
card and device:

```bash
aplay -D plughw:<CARD>,0 /tmp/neurosync-pifi-left.wav
```

## 4. Generate WAV test files

These commands use only the Python standard library and write WAV files;
they do not open an audio device.

```bash
python -m neurosync.audio.test_tone --channel left --freq 1000 --seconds 5 --out /tmp/neurosync-pifi-left.wav
python -m neurosync.audio.test_tone --channel right --freq 1000 --seconds 5 --out /tmp/neurosync-pifi-right.wav
python -m neurosync.audio.test_tone --channel both --freq 440 --seconds 5 --out /tmp/neurosync-pifi-both-440.wav
python -m neurosync.audio.test_tone --channel identify --freq 1000 --seconds 6 --out /tmp/neurosync-pifi-identify.wav
```

## 5. Play through the PiFi card

Use the card number found in step 3. If ALSA default is confirmed to be
the PiFi card, `-D default` is acceptable; explicit `plughw:<CARD>,0` is
preferred for bench notes.

```bash
aplay -D plughw:<CARD>,0 /tmp/neurosync-pifi-left.wav
aplay -D plughw:<CARD>,0 /tmp/neurosync-pifi-right.wav
aplay -D plughw:<CARD>,0 /tmp/neurosync-pifi-both-440.wav
aplay -D plughw:<CARD>,0 /tmp/neurosync-pifi-identify.wav
```

## 6. Bench measurements

Record all measurements in the Phase 1 bench log:

- Board identity: photo or written confirmation that the installed HAT is
  PiFi DAC+ V2.0 / PCM5122-compatible.
- ALSA identity: full `aplay -l` output and the selected `CARD,DEVICE`.
- Load: confirm each output is terminated into 10 kOhm high impedance.
- Left-only 1 kHz file: left output shows a 1 kHz sine; right output is
  silent except analyzer noise floor.
- Right-only 1 kHz file: right output shows a 1 kHz sine; left output is
  silent except analyzer noise floor.
- Both-channel 440 Hz file: both outputs show 440 Hz sine at matching
  level and phase for this wiring.
- Channel-identification file: left tone occurs first, then silence, then
  right tone.
- Level: measure RMS voltage on left and right. The board is specified as
  a 2 V RMS line-level DAC; record measured RMS and test amplitude used.
- Artifacts: note any clipping, dropouts, channel swap, audible noise, or
  unexpected card-ordering behavior.

Acceptance for Phase 1: ALSA enumerates the PiFi card after reboot, both
channels play through the expected card, channel isolation is correct, and
measured line-level output is consistent with the configured WAV amplitude
and the PiFi DAC+ 2 V RMS full-scale expectation.
