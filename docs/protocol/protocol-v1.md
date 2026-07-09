# Protocol v1 — Pi ↔ ESP32 USB serial

Status: **milestone 1 / safe discovery only**. This document,
`state-machine.md`, the Pi client, the ESP32 firmware, and the simulator
tests must stay in sync per `AGENTS.md`.

## Transport

- UART0 over the ESP32-WROOM-32 CP2102 USB serial bridge.
- 115200 baud, 8 data bits, no parity, 1 stop bit.
- Newline-delimited UTF-8 JSON. No binary protocol exists yet.
- Pi requests are compact single-line JSON objects and must be at most 512
  bytes before the terminating newline.
- The ESP32 reads serial with a timeout and never blocks indefinitely waiting
  for input. Serial parsing is ordinary task code, never ISR code.
- The protocol code is structured so the baud rate can later be raised to
  460800 after error-free testing.

## Request envelope

Every request has this shape:

```json
{"version":1,"sequence":1,"command":"hello"}
```

- `version` must be `1`.
- `sequence` must be a positive integer. Responses echo it.
- `command` is one of the milestone-1 commands below.

## Milestone-1 commands

Only these commands are implemented:

| Command | Purpose | Output effect |
|---|---|---|
| `hello` | Identify the controller and disabled capabilities | none |
| `get_status` | Report safe state, uptime, reset reason, fault count | none |
| `heartbeat` | Liveness check while remaining in `SAFE` | none |

`configure`, `arm`, `start`, and active `stop` behavior are intentionally
not implemented in milestone 1. DAC, ADC, PWM, MCPWM, LED, haptic,
Wi-Fi, Bluetooth, current-source control, and output-enable-high behavior
are also not implemented.

## Future Rev 5.4 command catalog (not implemented)

This table records the Rev 5.4 Appendix E command catalog so the protocol
shape is visible, but milestone 1 still implements only `hello`,
`get_status`, and `heartbeat`. The Pi client, ESP32 firmware, and tests
must not treat the commands below as available until a later protocol
change implements them across all consumers.

| Command | Future purpose | Milestone-1 status |
|---|---|---|
| `hello` | Identify the controller and disabled capabilities | implemented |
| `configure` | Load and validate a session configuration | not implemented |
| `arm` | Prepare a validated configuration for scheduled start | not implemented |
| `start` | Begin a scheduled or immediate run | not implemented |
| `stop` | Request ramp-down / stop behavior | not implemented |
| `get_status` | Report controller state and fault bits | implemented |
| `clear_fault` | Clear `FAULT` after explicit request and self-test | not implemented |
| `get_calibration` | Read stored calibration data | not implemented |
| `set_calibration` | Write calibration data | not implemented |
| `begin_capture` | Begin a capture window | not implemented |
| `read_capture` | Read captured samples | not implemented |

`heartbeat` remains a milestone-1 liveness command used by the current
safe-discovery implementation. It is not an output-control command and
does not energize any subsystem.

## Future Rev 5.4 fault bits (not implemented)

Fault-bit reporting is reserved for a later protocol milestone. Milestone 1
continues to report `faults: 0` from `get_status`.

| Bit | Name | Milestone-1 status |
|---:|---|---|
| `0x001` | `HEARTBEAT_TIMEOUT` | not implemented |
| `0x002` | `WATCHDOG_RESET` | not implemented |
| `0x004` | `ADC_SENSE_HIGH` | not implemented |
| `0x008` | `COMPLIANCE_LOSS` | not implemented |
| `0x010` | `INTERLOCK_OPEN` | not implemented |
| `0x020` | `HAPTIC_DEVICE_MISSING` | not implemented |
| `0x040` | `ADC_CONFIGURATION_ERROR` | not implemented |
| `0x080` | `DAC_CONFIGURATION_ERROR` | not implemented |
| `0x100` | `SERIAL_PROTOCOL_ERROR` | not implemented |
| `0x200` | `SUPPLY_OUT_OF_RANGE` | not implemented |
| `0x400` | `INTERNAL_STATE_ERROR` | not implemented |

## Responses

`hello` response:

```json
{
  "version": 1,
  "sequence": 1,
  "status": "ack",
  "command": "hello",
  "device": "neurosync-esp32",
  "firmware_version": "0.1.0",
  "git_commit": "unknown",
  "esp_idf_version": "5.x",
  "chip_model": "ESP32",
  "chip_revision": 3,
  "state": "SAFE",
  "output_enable": false,
  "capabilities": {
    "configure": false,
    "arm": false,
    "start": false,
    "dac": false,
    "adc": false,
    "pwm": false
  }
}
```

`get_status` response:

```json
{
  "version": 1,
  "sequence": 1,
  "status": "ack",
  "command": "get_status",
  "state": "SAFE",
  "output_enable": false,
  "uptime_ms": 1234,
  "reset_reason": "power-on",
  "faults": 0
}
```

`heartbeat` response:

```json
{
  "version": 1,
  "sequence": 1,
  "status": "ack",
  "command": "heartbeat",
  "state": "SAFE",
  "output_enable": false,
  "uptime_ms": 1234
}
```

## NAK errors

The ESP32 returns a NAK for malformed JSON, missing version, unsupported
version, missing sequence, missing command, unknown command, and oversized
input lines.

```json
{"version":1,"sequence":0,"status":"nak","error":"malformed_json"}
```

When the ESP32 cannot recover a request sequence, `sequence` is `0`;
otherwise the NAK echoes the request sequence.

## Message categories

| Category | Direction | Purpose |
|---|---|---|
| Discovery | Pi → ESP32 → Pi | Implemented as `hello` |
| Status | Pi → ESP32 → Pi | Implemented as `get_status` |
| Heartbeat | Pi ↔ ESP32 | Implemented as one safe liveness echo |
| Configuration | Pi → ESP32 | Not implemented |
| Arm / Start / Stop | Pi → ESP32 | Not implemented |
| Telemetry | ESP32 → Pi | Not implemented |
| Fault reporting | ESP32 → Pi | Not implemented beyond `faults: 0` |

## Hard invariant

**A USB packet arriving must never generate an individual 40 Hz edge or an
individual DAC sample.** All time-critical output generation is driven by
the ESP32's own timers/MCPWM peripherals once configured and armed — never
directly by serial packet arrival. See
`docs/architecture/system-architecture.md`.

## TODO before this protocol is "v1" in fact, not just in name

- Full message catalog with field-level definitions for configuration,
  session lifecycle, telemetry, and faults.
- Error/fault code catalog (cross-reference with `state-machine.md`).
