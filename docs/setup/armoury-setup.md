# Armoury setup

Armoury (this machine) is the authoritative development host for
NeuroSync Pro. This document is the quick path back to a working state;
`SETUP-REPORT.md` has the full record of what the initial setup run did.

## Prerequisites (already present on this machine)

- WSL2 Ubuntu 24.04, project on the native ext4 filesystem under
  `~/dev/projects/neurosync-pro` (never `/mnt/c`).
- `uv`, `git`, Claude Code, Codex CLI (installed by this setup — see
  Phase 7 of `SETUP-REPORT.md`).
- ESP-IDF toolchain under `~/esp/esp-idf-current` (see `esp32-setup.md`).

## Day-to-day commands

```bash
cd ~/dev/projects/neurosync-pro   # or: nsdev
uv sync
make doctor                        # or: nsdoctor
make check                         # lint + typecheck + test
```

## Editing

Open the folder in VS Code (`code .` from WSL, or via Remote-WSL). The
workspace is pre-configured (`.vscode/`) to use `.venv`, format/lint with
Ruff on save, and run pytest against `tests/unit`.

## Codex / Claude Code

Both tools are scoped to this project via `.codex/config.toml` and
`.claude/settings.json` respectively — see `AGENTS.md` and `CLAUDE.md` for
the rules they follow. The first time Codex runs here it will likely ask
you to trust the repository; approve that once per machine.

```bash
cd ~/dev/projects/neurosync-pro
codex     # or: nscodex
claude    # or your existing cc/cl launcher, scoped to this directory
```
