# ESP32 state machine

Status: **milestone 1 / safe discovery only**. Keep this document, the
firmware, the Pi client, and any simulator updated together (`AGENTS.md`).

Milestone 1 implements only the `SAFE` state surfaced over USB serial by
`hello`, `get_status`, and `heartbeat`. The broader lifecycle below is the
intended future shape, but no command currently transitions out of `SAFE`.

## States

```
RESET
  │ boot self-test OK
  ▼
SAFE
  │ configure
  ▼
CONFIGURED
  │ arm
  ▼
ARMED
  │ schedule
  ▼
SCHEDULED
  │ start time reached
  ▼
RUNNING
  │ stop / complete
  ▼
RAMP_DOWN
  │ ramp complete
  ▼
COMPLETE
  │ acknowledge completion
  ▼
SAFE

Any active state ── fault ──► FAULT
FAULT ── explicit clear + self-test OK ──► SAFE
```

Rev 5.4 state set, exactly:

`RESET`, `SAFE`, `CONFIGURED`, `ARMED`, `SCHEDULED`, `RUNNING`,
`RAMP_DOWN`, `COMPLETE`, `FAULT`.

## Rules

- **`RESET` is the boot state. `SAFE` is the first state reached after boot
  self-test succeeds and the firmware has forced outputs off.** `GPIO23`
  (output enable) is held low before any other peripheral is configured.
- In milestone 1, `hello`, `get_status`, and `heartbeat` all preserve
  `SAFE`, report `output_enable: false`, and perform no GPIO, DAC, ADC,
  PWM, MCPWM, LED, haptic, Wi-Fi, Bluetooth, or current-source action.
- The firmware verifies `GPIO23` is low before and after protocol command
  handling. Dynamic protocol commands do not modify GPIO configuration.
- Any fault (watchdog trip, heartbeat timeout, invalid configuration
  detected in hardware, out-of-range parameter) transitions immediately to
  `FAULT`, which forces the safe state. `FAULT` can transition back to
  `SAFE` only after an explicit clear and successful self-test — faults are
  never auto-cleared.
- `CONFIGURED` and `ARMED` do not themselves enable outputs; only
  `RUNNING` does, and only for parameters that were validated during
  `CONFIGURED`.
- `SCHEDULED` waits for the validated start time after arming.
- `RUNNING` exits through `RAMP_DOWN` and `COMPLETE`; no extra idle state
  is part of Rev 5.4.
- Loss of heartbeat from the Pi while in any active state is treated as a
  fault, not as "hold last state."

## TODO

- Exact timeout values (heartbeat interval, watchdog period).
- Full fault code catalog (cross-reference `protocol-v1.md`).
- Whether `RUNNING` has internal sub-states once real session behavior is
  defined.
