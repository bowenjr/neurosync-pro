# AGENTS.md — NeuroSync Pro operating rules

This file governs how Codex (and any other agent) operates in this
repository. `CLAUDE.md` applies the same rules to Claude Code and defers to
this file rather than duplicating it.

## What this project is

NeuroSync Pro is an **instrumented bench-learning platform**. Every output
in the system terminates in a dummy load, an optical fixture, a line-level
load, or a fixed mechanical fixture.

**No biological connection or use is permitted, anywhere, at any layer,
ever.** This is not a configuration option — it is a permanent constraint
on the project itself.

## System of record

- **Armoury** (this development machine) is the **authoritative source**
  for all code, firmware, configuration, and documentation.
- The **Raspberry Pi 3** (`neurosync-pi`) is a **deployment target**. It
  runs code built and versioned on Armoury; it is never a place to make
  one-off edits that don't exist here first.
- The **ESP32** (ESP32-WROOM-32, IDF target `esp32`) is a **firmware
  target**. Its firmware source lives in `firmware/esp32/` on Armoury; the
  chip itself only ever holds a build of what's already committed here.
- **No source exists only on a target.** If you find yourself wanting to
  edit something directly on the Pi or infer firmware behavior from what's
  currently flashed rather than from `firmware/esp32/`, stop — pull it back
  into the repository first.

## Build vs. flash vs. deploy

- **Build automatically.** `idf.py build`, `uv run pytest`, `ruff`, `mypy`,
  and similar build/check steps may run without asking, subject to the
  command-specific rules below and to `.claude/settings.json` /
  `.codex/config.toml` sandboxing.
- **Flash only after explicit human approval**, given for that specific
  flash. A prior approval does not carry forward to the next flash.
  `scripts/esp32/flash.sh` enforces `--confirm` and a set of pre-flight
  checks; do not bypass it by calling `idf.py flash` directly.
- **Deploy only after explicit human approval**, given for that specific
  deployment. `scripts/pi/deploy.sh` enforces `--confirm`; do not bypass it
  with a raw `rsync`/`ssh` sequence.
- Never chain "build, then flash" or "build, then deploy" into one
  unsupervised action. Each flash and each deploy is its own approval.

## Hardware outputs

- All hardware outputs default to **off** / safe state, on both the ESP32
  and anything the Pi supervises. This is enforced at firmware boot (see
  `firmware/esp32/main/nsp_safe_state.c`) and must not be weakened.
  `GPIO23` (OUTPUT_ENABLE) is held low immediately at startup, before any
  other peripheral configuration.
- No agent enables a GPIO output, starts a PWM/MCPWM channel, or drives a
  DAC as part of routine setup, testing, or "let me just check" debugging.
  If a task appears to require energizing an output, stop and ask.

## Protocol changes

The USB serial protocol (`docs/protocol/protocol-v1.md`,
`docs/protocol/state-machine.md`) is shared across four consumers: the Pi
supervisory app, the ESP32 firmware, any simulator/test harness, and the
documentation itself. **A protocol change is not done until all four are
updated together in the same change set**: Pi-side client code, ESP32-side
firmware, the simulator/tests that exercise the protocol, and the protocol
docs. Partial protocol changes (e.g., firmware accepts a new command but
docs and Pi client don't know about it) are treated as incomplete work.

## Hardware change discipline

When changing anything that affects physical behavior (timing constants,
gain, pin mapping, output topology, PWM frequency, etc.), change **one
variable at a time** and note what changed and why. Do not bundle multiple
hardware-affecting changes into a single untested step.

## Git

- No destructive Git commands: no `git reset --hard`, `git clean -fd`,
  force-push, history rewrite, or branch deletion without explicit
  human approval for that specific action.
- Commits and pushes themselves also require explicit approval in this
  repository (see `.claude/settings.json`) — this project does not
  auto-commit.

## File sync / deployment safety

- **No `rsync --delete`**, ever, in any script or ad hoc command touching
  the Raspberry Pi. Deployment is additive/overwriting of tracked files
  only; it does not prune the remote directory.
- `scripts/pi/deploy.sh` excludes `.git`, `.venv`, build directories,
  `measurements/raw`, and secrets from the sync by construction — don't
  work around those exclusions.

## Flashing safety

- **No flash erase.** `esptool erase_flash` / `idf.py erase-flash` are
  denied outright (see `.claude/settings.json`), not just gated behind
  confirmation. There is no supported workflow in this repository that
  erases the ESP32's flash.
- `scripts/esp32/flash.sh` never erases before writing; it flashes the
  built application image only.

## Practical guidance for agents

- Prefer the scripts in `scripts/` and the `make` targets in `Makefile`
  over inventing equivalent one-off shell commands — they encode the
  approval gates and safety checks described above.
- When unsure whether an action counts as "flashing," "deploying," or
  "enabling an output," treat it as if it does and ask first.
- Read `docs/architecture/trust-boundaries.md` before making changes that
  cross the Armoury/Pi/ESP32 boundary.
