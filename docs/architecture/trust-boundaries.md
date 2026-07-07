# Trust boundaries

This document states what each side of each boundary is allowed to assume
about the other — and, just as importantly, what it must *not* assume.

## Armoury ↔ Raspberry Pi

- Armoury assumes the Pi will run **exactly** the committed source it was
  deployed with (`scripts/pi/deploy.sh`) — never code edited only on the
  Pi. If the Pi's running state and the repository diverge, the repository
  wins and the Pi should be redeployed, not hand-patched.
- The Pi does not assume Armoury is reachable at runtime. It must be able
  to run its supervisory duties (logging, session orchestration) without a
  live connection back to the dev machine.
- Deployment (`scripts/pi/deploy.sh`) never deletes files on the Pi beyond
  what rsync overwrites for tracked paths (no `--delete`), and never
  restarts services unless `--restart` is explicitly passed. The Pi's own
  local state (logs, measurement captures) is not something Armoury
  clobbers on deploy.

## Raspberry Pi ↔ ESP32

- The Pi assumes the ESP32 is the **sole authority** on output state. The
  Pi never assumes an output is off just because it didn't ask for it to be
  on — it queries/observes ESP32-reported state.
- The ESP32 does not trust the Pi to enforce timing. All deterministic
  timing (MCPWM, DAC/ADC cadence) is generated on-chip from configured
  parameters, not from the rate or timing of incoming serial packets. A
  slow, jittery, or temporarily disconnected Pi must never be able to
  change output timing or accidentally pulse an output.
- The ESP32 does not trust the Pi to keep it safe. Watchdogs, heartbeat
  timeout handling, and fault shutdown live on the ESP32 and default to the
  safe state independent of whether the Pi is behaving correctly.
- The Pi does not send raw/low-level hardware commands over the serial
  link — only protocol-v1 messages (discovery, configuration, arm/start/
  stop, heartbeat, telemetry, fault reporting). See
  `docs/protocol/protocol-v1.md`.

## Human ↔ agents (Codex / Claude Code)

- Agents assume they may build, lint, type-check, and test freely.
- Agents must not assume prior approval carries forward: each flash
  (`scripts/esp32/flash.sh`) and each deploy (`scripts/pi/deploy.sh`)
  requires its own explicit human `--confirm`/`CONFIRM=YES` for that
  specific action.
- Agents must not assume an ambiguous request implies permission to enable
  a hardware output, erase flash, force-push, or run a destructive Git
  command — the default on ambiguity is to stop and ask (see `AGENTS.md`).
