# ESP32 state machine

Status: **milestone 1 / safe discovery only**. Keep this document, the
firmware, the Pi client, and any simulator updated together (`AGENTS.md`).

Milestone 1 implements only the `SAFE` state surfaced over USB serial by
`hello`, `get_status`, and `heartbeat`. The broader lifecycle below is the
intended future shape, but no command currently transitions out of `SAFE`.

## States

```
        boot
         │
         ▼
  ┌─────────────┐   fault / heartbeat timeout   ┌────────────┐
  │    SAFE      │◄──────────────────────────────│  FAULTED   │
  └──────┬───────┘                               └─────▲──────┘
         │ configure                                    │ fault
         ▼                                               │
  ┌─────────────┐        arm         ┌─────────────┐     │
  │ CONFIGURED   │──────────────────►│    ARMED    │─────┤
  └─────────────┘                    └──────┬──────┘     │
                                             │ start      │
                                             ▼            │
                                      ┌─────────────┐     │
                                      │   RUNNING    │────┘
                                      └──────┬──────┘
                                             │ stop / complete
                                             ▼
                                       SAFE_IDLE
```

## Rules

- **`SAFE` is the boot state and the only state in which the firmware
  is guaranteed to have just forced outputs off.** `GPIO23` (output enable)
  is held low before any other peripheral is configured.
- In milestone 1, `hello`, `get_status`, and `heartbeat` all preserve
  `SAFE`, report `output_enable: false`, and perform no GPIO, DAC, ADC,
  PWM, MCPWM, LED, haptic, Wi-Fi, Bluetooth, or current-source action.
- The firmware verifies `GPIO23` is low before and after protocol command
  handling. Dynamic protocol commands do not modify GPIO configuration.
- Any fault (watchdog trip, heartbeat timeout, invalid configuration
  detected in hardware, out-of-range parameter) transitions immediately to
  `FAULTED`, which forces the safe state and requires an explicit
  Pi-initiated reset back to `SAFE` — faults are never auto-cleared.
- `CONFIGURED` and `ARMED` do not themselves enable outputs; only
  `RUNNING` does, and only for parameters that were validated during
  `CONFIGURED`.
- Loss of heartbeat from the Pi while `ARMED` or `RUNNING` is treated as a
  fault, not as "hold last state."

## TODO

- Exact timeout values (heartbeat interval, watchdog period).
- Full fault code catalog (cross-reference `protocol-v1.md`).
- Whether `RUNNING` has internal sub-states once real session behavior is
  defined.
