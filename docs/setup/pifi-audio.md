# PiFi DAC+ Phase 1 audio verification

Phase 1 verifies that the PiFi DAC+ V2.0 produces correct stereo
line-level audio from the Raspberry Pi 3 target running Raspberry Pi OS
Trixie. This is a bench-only procedure; do not connect biological loads.

Safety note: the PiFi RCA outputs must connect only to a 10 kOhm
high-impedance oscilloscope or measurement input. Do not connect speakers,
low-impedance headphones, or an amplifier.

## Hardware and overlay assumption

The PiFi DAC+ V2.0 is a PCM5122 DAC+ board. On the verified Raspberry Pi
OS Trixie target with kernel `6.18.34+rpt-rpi-v8`, the expected overlay is:

```ini
dtoverlay=hifiberry-dacplus-std
```

If `hifiberry-dacplus-std.dtbo` is absent on an older kernel, use the
fallback:

```ini
dtoverlay=hifiberry-dacplus
```

Do not use the non-plus DAC overlay.

## 1. Mount the HAT

1. Shut down the Raspberry Pi 3 cleanly.
2. Disconnect power from the Pi.
3. Seat the PiFi DAC+ V2.0 on the 40-pin GPIO header.
4. Verify pin 1 alignment before applying power.
5. Connect left and right RCA outputs only to a 10 kOhm high-impedance
   oscilloscope or measurement input.
6. Reconnect power and boot the Pi.

## 2. Deploy the tooling from Armoury

The Pi is a deployment target, not a source editing location. From Armoury:

```bash
make pi-deploy CONFIRM=YES
```

Do not run `git pull`, edit files, or create commits on the Pi.

## 3. Confirm overlay availability on the Pi

On the Pi, run the read-only overlay check before editing boot config:

```bash
uname -r
ls -1 /boot/firmware/overlays/hifiberry-dacplus*.dtbo
```

Use `hifiberry-dacplus-std` when
`/boot/firmware/overlays/hifiberry-dacplus-std.dtbo` exists. If it is
absent but `hifiberry-dacplus.dtbo` exists, use `hifiberry-dacplus`.

## 4. Back up and enable the overlay

Create a manual backup first:

```bash
sudo cp -p /boot/firmware/config.txt /boot/firmware/config.txt.manual-pifi-backup
```

Then run the configure script with the verified overlay:

```bash
scripts/pi/configure-pifi.sh --dry-run --overlay=hifiberry-dacplus-std
scripts/pi/configure-pifi.sh --confirm --overlay=hifiberry-dacplus-std
```

If the std overlay is absent and the fallback was confirmed:

```bash
scripts/pi/configure-pifi.sh --dry-run --overlay=hifiberry-dacplus
scripts/pi/configure-pifi.sh --confirm --overlay=hifiberry-dacplus
```

Review the dry-run output before running the confirmed write. The script
also creates a timestamped backup, removes any existing active
`dtoverlay=hifiberry-*` line so only one audio overlay remains, rewrites
`dtparam=audio=on` to `dtparam=audio=off`, enables commented or missing
`dtparam=i2s=on`, and writes exactly one selected DAC+ overlay line.

Reboot after configuration:

```bash
sudo reboot
```

## 5. Confirm ALSA and kernel health after reboot

```bash
aplay -l
aplay -L | grep -Ei 'sndrpihifiberry|dacplus|hifiberry'
scripts/pi/verify-pifi.sh
dmesg | grep -iE "pcm512|hifiberry|i2s"
```

Acceptance requires more than card enumeration. The kernel log must not
show PCM512x probe, reset, SCLK/BCLK, timeout, or related failure errors.

The stable playback device is expected to be:

```text
plughw:CARD=sndrpihifiberry,DEV=0
```

The exact card name may include `dacplus`; confirm with `aplay -L` and use
the stable `CARD=...` name it reports.

## 6. Generate WAV test files

Run these on the deployed Pi from the app directory. Use the project venv,
not system Python:

```bash
.venv/bin/python -m neurosync.audio.test_tone --channel left --freq 1000 --seconds 5 --out /tmp/neurosync-pifi-left.wav
.venv/bin/python -m neurosync.audio.test_tone --channel right --freq 1000 --seconds 5 --out /tmp/neurosync-pifi-right.wav
.venv/bin/python -m neurosync.audio.test_tone --channel both --freq 440 --seconds 5 --out /tmp/neurosync-pifi-both-440.wav
.venv/bin/python -m neurosync.audio.test_tone --channel identify --freq 1000 --seconds 6 --out /tmp/neurosync-pifi-identify.wav
```

The generator prints the linear amplitude, dBFS, and expected RMS voltage
to stderr. The default amplitude is 0.25, so the expected line-level RMS is
about 0.53 V into high impedance when the mixer is at 0 dB. Use
`--full-scale` only for a deliberate full-scale check; it expects about
2.10 V RMS.

## 7. Play through the PiFi card

Use the stable card name confirmed from `aplay -L`:

```bash
aplay -D plughw:CARD=sndrpihifiberry,DEV=0 /tmp/neurosync-pifi-left.wav
aplay -D plughw:CARD=sndrpihifiberry,DEV=0 /tmp/neurosync-pifi-right.wav
aplay -D plughw:CARD=sndrpihifiberry,DEV=0 /tmp/neurosync-pifi-both-440.wav
aplay -D plughw:CARD=sndrpihifiberry,DEV=0 /tmp/neurosync-pifi-identify.wav
```

If `aplay -L` reports a slightly different stable card name, substitute
that exact `CARD=...` value.

## 8. Bench measurements

Record all measurements in the Phase 1 bench log:

- Board identity: photo or written confirmation that the installed HAT is
  PiFi DAC+ V2.0 / PCM5122-compatible.
- Overlay identity: `uname -r`, overlay file list, and the chosen
  `dtoverlay`.
- ALSA identity: full `aplay -l`, relevant `aplay -L` lines, and the
  selected stable playback device.
- Kernel health: relevant `dmesg` lines showing no PCM512x probe, reset,
  SCLK/BCLK, timeout, or failure errors.
- Load: each RCA output terminated only into 10 kOhm high impedance and
  scope/analyzer input; no speakers, headphones, or amp.
- Channel mapping: left-only file produces the coherent 1 kHz tone on the
  left output and no coherent same-scale 1 kHz tone on the right; right-only
  file does the inverse. The generated inactive channel is mathematical
  zero, but the analog measurement gate is absence of a coherent tone at
  the same scale, not absolute zero noise.
- Frequency: measured frequency matches the generated file within counter
  accuracy.
- Voltage: RMS voltage matches the generated amplitude and the PCM5122
  2.1 V RMS at 0 dBFS expectation. Default amplitude 0.25 should measure
  about 0.53 V RMS at mixer 0 dB; full-scale should measure about
  2.10 V RMS.
- DC offset: near 0 V on both channels.
- Clipping/artifacts: no clipping, dropouts, channel swap, or unexpected
  audible/noise behavior.
- Stability: 30 seconds of playback with no underruns and no new kernel
  errors.

Acceptance for Phase 1: the correct DAC+ overlay is active, ALSA exposes
the PiFi card under a stable device name, kernel logs are clean, both
channels map correctly, frequency and voltage match the generated files,
DC offset is near 0 V, and 30-second playback is stable.
