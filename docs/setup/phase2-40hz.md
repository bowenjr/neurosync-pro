# Phase 2 bench 40 Hz sync output

Phase 2 adds a bench-only ESP32 firmware build that drives
`NSP_GPIO_SYNC` (`GPIO19`) with a hardware-timed 40.000 Hz, 50% duty square
wave using MCPWM. GPIO19 is a logic reference for scope verification only.
Probe GPIO19 with a high-impedance oscilloscope input; do not attach any
load.

This is not production firmware. `GPIO23` output-enable remains low for
the entire test, and every non-sync output remains in the safe-low set.

## Build the production-default image

From Armoury:

```bash
cd firmware/esp32
source ~/esp/esp-idf-current/export.sh
idf.py set-target esp32
idf.py build
```

With `CONFIG_NSP_BENCH_SYNC_40HZ` unset, behavior is unchanged: GPIO19 is
held low in `SAFE`, no MCPWM output is active, and the firmware remains in
the milestone-1 safe-discovery state.

## Build the bench sync image

Enable the bench flag locally through menuconfig:

```bash
cd firmware/esp32
source ~/esp/esp-idf-current/export.sh
idf.py set-target esp32
idf.py menuconfig
```

Set:

```text
NeuroSync Pro bench options
  [*] Bench-only 40 Hz sync output on GPIO19
```

Then build:

```bash
idf.py build
```

The boot log must contain:

```text
*** BENCH BUILD: 40Hz sync active on GPIO19 -- NOT production firmware ***
```

## Flash and monitor

Flashing is a human-approved action. Do not erase flash.

```bash
cd ~/dev/projects/neurosync-pro
make esp32-flash CONFIRM=YES
make esp32-monitor
```

The supported flash script writes the built application image and does not
run `erase_flash` / `erase-flash`.

## Scope acceptance

Connect only a high-impedance oscilloscope probe and ground reference:

- Probe: GPIO19 (`NSP_GPIO_SYNC`) to scope input.
- Scope input: high-Z.
- Expected waveform: square wave, 0 V to ESP32 logic high.
- Frequency: 40.000 Hz, within +/-0.1%.
- Period: 25.000 ms.
- High time: 12.500 ms.
- Low time: 12.500 ms.
- Duty cycle: 50%, within measurement tolerance.
- GPIO23 output-enable: remains low.
- No other output pin changes state.
- No CPU loop or ISR should be needed to maintain edges; MCPWM free-runs.

The exact divider used by firmware is documented in
`firmware/esp32/main/nsp_sync.c`.

## Return to production firmware

Disable `CONFIG_NSP_BENCH_SYNC_40HZ`, rebuild, and reflash with explicit
human approval:

```bash
cd firmware/esp32
idf.py menuconfig
# clear NeuroSync Pro bench options -> Bench-only 40 Hz sync output on GPIO19
idf.py build
cd ../..
make esp32-flash CONFIRM=YES
```

After the production-default image is flashed, GPIO19 returns to the
safe-low list and is held low in `SAFE`.
