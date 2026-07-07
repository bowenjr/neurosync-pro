# CLAUDE.md — NeuroSync Pro

This project's operating rules are defined in **[AGENTS.md](AGENTS.md)** and
apply equally to Claude Code. Read it before doing any non-trivial work
here — it is not optional background reading, it is the contract for this
repository. In summary, it covers:

- Armoury is the authoritative source; the Raspberry Pi 3 and ESP32 are
  deployment/firmware targets only — no source lives only on a target.
- Build automatically; **flash and deploy only after explicit, per-action
  human approval**.
- No biological connection or use, anywhere, ever.
- Hardware outputs default off; nothing enables an output as a side effect
  of setup or debugging.
- Protocol changes touch Pi, ESP32, simulator/tests, and docs together.
- One hardware variable at a time.
- No destructive Git commands, no `rsync --delete`, no flash erase.

## Architecture references

- `docs/architecture/system-architecture.md` — how Armoury, the Pi, and the
  ESP32 divide responsibility, and how the USB serial link connects them.
- `docs/architecture/raspberry-pi-3-deviation.md` — where this project's
  assumptions differ because the target is a Pi 3, not a Pi 5.
- `docs/architecture/trust-boundaries.md` — what each side of a boundary is
  allowed to assume about the other.
- `docs/protocol/protocol-v1.md` and `docs/protocol/state-machine.md` — the
  USB serial protocol and the ESP32 state machine it drives.

## This project's permissions

This directory has its own `.claude/settings.json` (Phase 6 of the initial
setup) that auto-allows read-only inspection and build/lint/test commands,
requires confirmation for `sudo`, remote Pi changes, flashing, and commits,
and denies destructive operations outright. It does not modify or override
`~/.claude/settings.json`.

## Useful entry points

- `make doctor` — safe, read-only environment health check.
- `uv run neurosync doctor|pi-info|serial-list|audio-list` — read-only CLI.
- `scripts/` and the `Makefile` targets documented there are the supported
  way to touch the Pi or the ESP32; see `docs/setup/codex-direct-control.md`
  for example agent-driven workflows and their approval gates.
