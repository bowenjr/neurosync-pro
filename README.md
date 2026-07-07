# NeuroSync Pro

Instrumented bench-learning platform. **Bench-test hardware only** — all outputs
terminate in dummy loads, optical fixtures, line-level loads, or fixed
mechanical fixtures. No biological connection or use is permitted at any
layer of this project.

See [AGENTS.md](AGENTS.md) for the operating rules followed by Codex and
Claude Code in this repository, and `docs/architecture/` for the system
design.

## Architecture at a glance

- **Armoury** (this machine) — authoritative source, build host for both
  targets.
- **Raspberry Pi 3** (`neurosync-pi`) — supervisory application, config,
  PiFi audio, logging, synthetic data, future touchscreen HMI, session
  orchestration.
- **ESP32** (`esp32` / ESP32-WROOM-32) — local deterministic timing, MCPWM,
  DAC/ADC, state machine, output gating, watchdogs, heartbeat, fault
  shutdown.
- USB serial link between Pi and ESP32 handles discovery, configuration,
  arm/start/stop, heartbeat, telemetry, and fault reporting — never
  individual 40 Hz edges or DAC samples over the wire.

## Quick start (Armoury)

```bash
uv sync
uv run neurosync doctor
```

See `docs/setup/armoury-setup.md`, `docs/setup/raspberry-pi-setup.md`, and
`docs/setup/esp32-setup.md` for full setup instructions, and
`docs/setup/SETUP-REPORT.md` for the record of this environment's initial
setup run.

## Safety

No command in this repository enables a hardware output, flashes firmware,
or deploys to the Raspberry Pi without an explicit `--confirm`/`CONFIRM=YES`
flag supplied by a human. See `AGENTS.md` for the full rule set.
