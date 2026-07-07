# Protocol v1 — Pi ↔ ESP32 USB serial

Status: **draft / placeholder**, established during initial environment
setup so `AGENTS.md`'s "protocol changes touch four places together" rule
has something concrete to point at. Fill in wire-format details as the
supervisory app and firmware are actually implemented; keep this file,
`state-machine.md`, the Pi client, the ESP32 firmware, and any simulator in
sync per `AGENTS.md`.

## Transport

- USB CDC-ACM serial, line-oriented, UTF-8 text framing (see
  `src/neurosync/control/serial_link.py` for the Pi-side transport helper).
- Baud rate, framing, and message encoding (e.g., newline-delimited JSON vs.
  a compact binary format) are **TODO** — decide before implementing the
  ESP32-side parser, not after.

## Message categories

| Category | Direction | Purpose |
|---|---|---|
| Discovery | Pi → ESP32 → Pi | Identify firmware version, chip info, capabilities |
| Configuration | Pi → ESP32 | Set timing/gain/topology parameters before arming |
| Arm / Start / Stop | Pi → ESP32 | Session lifecycle control |
| Heartbeat | Pi ↔ ESP32 | Liveness; ESP32 enters safe state on heartbeat timeout |
| Telemetry | ESP32 → Pi | Status/measurement reporting during a session |
| Fault reporting | ESP32 → Pi | Watchdog trips, invalid config, hardware faults |

## Hard invariant

**A USB packet arriving must never generate an individual 40 Hz edge or an
individual DAC sample.** All time-critical output generation is driven by
the ESP32's own timers/MCPWM peripherals once configured and armed — never
directly by serial packet arrival. See
`docs/architecture/system-architecture.md`.

## TODO before this protocol is "v1" in fact, not just in name

- Exact message framing and encoding.
- Full message catalog with field-level definitions.
- Versioning/compatibility strategy between Pi client and ESP32 firmware.
- Error/fault code catalog (cross-reference with `state-machine.md`).
