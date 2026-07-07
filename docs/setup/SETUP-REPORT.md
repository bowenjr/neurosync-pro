# NeuroSync Pro — Initial Setup Report

Run date: 2026-07-07
Host: Armoury (Windows 11 + WSL2 Ubuntu 24.04.3 LTS, user `bowen`)

## What was detected

See `docs/setup/system-audit.md` for the full read-only audit. Highlights:
git 2.43.0, uv 0.11.7, Python 3.12.3 (system) + 3.13.13 (uv-managed) +
3.11.15 (project venv, uv-provisioned), Node v24.15.0, Claude Code 2.1.202,
VS Code CLI 1.127.0. Codex CLI, mypy, pytest, and shellcheck were **not**
installed at audit time. No prior `neurosync-pro` repository, no existing
ESP-IDF install, `bowen` not in `dialout`, no `neurosync-pi` SSH alias,
`neurosync-pi.local` unreachable, no ESP32 attached, `usbipd.exe` not on
the WSL-visible PATH.

## What was installed

| Item | Version | Location |
|---|---|---|
| Project Python venv | 3.11.15 (uv-provisioned) | `~/dev/projects/neurosync-pro/.venv` |
| Codex CLI | 0.142.5 | `~/.codex/packages/standalone/...`, symlinked on `~/.local/bin` |
| ESP-IDF | v5.5.4 (highest stable non-RC v5.x tag) | `~/esp/esp-idf-5.5.4`, symlinked at `~/esp/esp-idf-current` |
| ESP-IDF toolchain (partial) | xtensa-esp-elf-gdb, xtensa-esp-elf, esp32ulp-elf | `~/.espressif/tools/` |
| VS Code extensions | Remote SSH, C/C++ (`ms-vscode.cpptools`), ESP-IDF (`espressif.esp-idf-extension`) | user profile |
| Dedicated SSH key | ed25519 | `~/.ssh/id_ed25519_neurosync` (+ `.pub`) |

**Not completed:** ESP-IDF's `install.sh esp32` did not finish — it failed
partway through installing `openocd-esp32` because the system is missing
`libusb-1.0.so.0`, and as a result never created the Python virtual
environment `idf.py` requires. This needed `sudo apt-get install`, which
requires an interactive password this session could not supply. See
`manual-actions.md` item 1 — one command finishes it.

## Exact paths / files created (86 new files in the repository)

Top-level: `AGENTS.md`, `CLAUDE.md`, `README.md`, `Makefile`,
`pyproject.toml`, `uv.lock`, `.gitignore`, `.python-version`.

- `.claude/settings.json` (project-scoped permissions)
- `.codex/config.toml`
- `.vscode/{settings,tasks,launch,extensions}.json`
- `config/hardware.env.example`, `config/hardware_manifest.example.json`,
  `config/toolchain-lock.json`
- `docs/architecture/{system-architecture,raspberry-pi-3-deviation,trust-boundaries}.md`
- `docs/protocol/{protocol-v1,state-machine}.md`
- `docs/setup/{system-audit,armoury-setup,raspberry-pi-setup,esp32-setup,codex-direct-control,manual-actions,rollback,SETUP-REPORT}.md`
- `firmware/esp32/` — `CMakeLists.txt`, `sdkconfig.defaults`,
  `partitions.csv`, `main/{CMakeLists.txt,app_main.c,nsp_board.h,nsp_safe_state.c}`,
  `test/README.md`
- `infra/pi/systemd/neurosync-supervisor.service.template`
- `scripts/common/lib.sh`
- `scripts/esp32/{detect,build,flash,monitor,flash-monitor,chip-info}.sh`
- `scripts/pi/{status,inventory,bootstrap,deploy,test,logs,shell,install-services,remove-services}.sh`
- `scripts/windows/esp32-usb-{list,bind,attach,detach}.ps1`
- `scripts/doctor/neurosync-doctor.sh`
- `src/neurosync/{control/{config,hardware_discovery,serial_link,cli}.py, __init__ files}`
- `tests/unit/{test_config,test_hardware_discovery}.py`
- `.gitkeep` placeholders in otherwise-empty directories

## Files modified (outside the repository, all backed up first)

| File | Change | Backup |
|---|---|---|
| `~/.ssh/config` | Appended idempotent `Host neurosync-pi` block | `~/.ssh/config.bak.20260707_102129` |
| `~/.bashrc` | Appended idempotent `neurosync-pro` marked section (nsdev/nsdoctor/nspi/nsesp/nsbuild/nscodex/nsclaude) | `~/.bashrc.bak.20260707_100216` and a second timestamped backup before the Phase 16 edit |

`~/.claude/settings.json`, `~/.claude/CLAUDE.md`, and `~/.mcp.json` were
**not** modified, per the setup constraints.

## Files created outside the repository

- `~/.config/neurosync/hardware.env` (uncommitted, mode 600, safe defaults
  + TODOs for the still-unreachable Pi and not-yet-attached ESP32)
- `~/bin/neurosync-idf` (sources the selected ESP-IDF `export.sh`, execs
  its arguments)
- `~/.ssh/id_ed25519_neurosync[.pub]`
- `~/esp/esp-idf-5.5.4/`, `~/esp/esp-idf-current` (symlink)

## Test results

```
uv run ruff check .     -> All checks passed!
uv run mypy src          -> Success: no issues found in 10 source files
uv run pytest             -> 6 passed
```

`neurosync doctor|pi-info|serial-list|audio-list` were manually
smoke-tested and all produced correct, read-only output (0 serial ports, no
audio devices, not a Raspberry Pi, x86_64 — all correct for Armoury).

`scripts/doctor/neurosync-doctor.sh` (`make doctor`) run result at time of
this report: **16 PASS, 8 WARN, 1 FAIL** — see the Blockers table below,
all WARN/FAIL entries trace directly to the manual actions list.

## Raspberry Pi status

**Unreachable** (`neurosync-pi.local` did not resolve during setup). All
Pi-side scripts (`status.sh`, `inventory.sh`, `bootstrap.sh`, `deploy.sh`,
`test.sh`, `logs.sh`, `shell.sh`, `install-services.sh`,
`remove-services.sh`) were written and are ready to use but none were
executed against the Pi. No `hardware/manifests/raspberry-pi.json` exists
yet — it's written by `inventory.sh`/`bootstrap.sh` once the Pi is
reachable.

## ESP32 status

No board was attached during setup. ESP-IDF v5.5.4 is cloned; the toolchain
install is incomplete (see above). Firmware source
(`firmware/esp32/main/`) is written: no Wi-Fi, no Bluetooth, no DAC/ADC/PWM
operation, `GPIO23` and four placeholder output pins forced low as the
first action in `app_main`, prints identification + a 5-second heartbeat,
runs indefinitely. Pin map is protected by compile-time `_Static_assert`
checks (`nsp_board.h`). **Not built, not flashed** — building requires
finishing the toolchain install first.

## Unresolved TODOs

- `NEUROSYNC_ESP32_PORT=auto` in `~/.config/neurosync/hardware.env` — set
  once a board is attached and `scripts/esp32/detect.sh` identifies it.
- `NEUROSYNC_PI_HOSTNAME=neurosync-pi.local` — confirm this still resolves
  once the Pi is back on the network, or replace with a static IP.
- `config/hardware_manifest.example.json` fields are all `TODO` —
  real values land in `hardware/manifests/raspberry-pi.json` via
  `scripts/pi/inventory.sh`, not by hand-editing the example.
- Exact touchscreen and PiFi board identity (never probed — out of scope
  per the setup constraints).
- `docs/protocol/protocol-v1.md` and `state-machine.md` are intentionally
  draft/placeholder — wire format and full message/fault catalogs are TODO
  once real Pi↔ESP32 behavior is implemented.

## Manual actions still required

See `docs/setup/manual-actions.md` for full commands. Summary:

1. `sudo apt-get install ...` (ESP-IDF prerequisites + shellcheck), then
   re-run `~/esp/esp-idf-current/install.sh esp32`.
2. `sudo usermod -aG dialout bowen`, then `wsl --shutdown` from Windows.
3. Install usbipd-win on Windows.
4. Bind/attach the ESP32 via the `scripts/windows/esp32-usb-*.ps1` helpers
   once a board is connected.
5. `ssh-copy-id -i ~/.ssh/id_ed25519_neurosync.pub bowen@neurosync-pi.local`
   once the Pi is reachable.
6. Trust the repository the first time Codex runs here.
7. Identify the exact touchscreen and PiFi board hardware.
8. Approve ESP32 flashing when the time comes
   (`make esp32-flash CONFIRM=YES`).
9. Approve Pi bootstrap/deploy when the time comes
   (`make pi-bootstrap CONFIRM=YES`, `make pi-deploy CONFIRM=YES`).

## Rollback

See `docs/setup/rollback.md` for exact commands to undo any part of this
setup — everything added is additive and independently removable; nothing
destructive was done to pre-existing state.

## Next recommended step

Run the single `sudo apt-get install` command in `manual-actions.md` item
1, then `~/esp/esp-idf-current/install.sh esp32` — that unblocks both
`make esp32-build` and `make doctor` going fully green on the Armoury side.
The Raspberry Pi side is blocked purely on the Pi being reachable on the
network; once it is, `make pi-status` is the first thing to run.
