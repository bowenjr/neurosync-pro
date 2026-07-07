# ESP32 state machine

Status: **draft / placeholder**, to be refined alongside `protocol-v1.md`
and the firmware in `firmware/esp32/`. Keep this document, the firmware,
the Pi client, and any simulator updated together (`AGENTS.md`).

## States

```
        boot
         │
         ▼
  ┌─────────────┐   fault / heartbeat timeout   ┌────────────┐
  │  SAFE_IDLE   │◄──────────────────────────────│  FAULTED   │
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

- **`SAFE_IDLE` is the boot state and the only state in which the firmware
  is guaranteed to have just forced outputs off.** `GPIO23` (output enable)
  is held low before any other peripheral is configured.
- Any fault (watchdog trip, heartbeat timeout, invalid configuration
  detected in hardware, out-of-range parameter) transitions immediately to
  `FAULTED`, which forces the safe state and requires an explicit
  Pi-initiated reset back to `SAFE_IDLE` — faults are never auto-cleared.
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
