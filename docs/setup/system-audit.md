# NeuroSync Pro — System Audit

Generated: 2026-07-07 (setup run, Phase 1)
Host: Armoury (Windows 11 + WSL2 Ubuntu 24.04, user `bowen`)

## WSL / Kernel

- `uname -a`: `Linux Armoury 6.6.87.2-microsoft-standard-WSL2 #1 SMP PREEMPT_DYNAMIC Thu Jun 5 18:30:46 UTC 2025 x86_64`
- Ubuntu: 24.04.3 LTS (noble)
- Working directory at audit time: `/home/bowen/dev/projects`
- WSL/Windows interop (`powershell.exe`) is reachable from WSL.

## Toolchain versions

| Tool | Version | Notes |
|---|---|---|
| git | 2.43.0 | |
| uv | 0.11.7 | |
| python3 (system) | 3.12.3 | `/usr/bin/python3`, `/usr/bin/python3.12` |
| python3.13 | 3.13.13 | uv-managed, symlinked at `~/.local/bin/python3.13` -> `~/.local/share/uv/python/cpython-3.13-linux-x86_64-gnu/bin/python3.13` |
| node | v24.15.0 | |
| npm | 11.12.1 | |
| Claude Code | 2.1.202 | |
| Codex CLI | **not installed** | `codex` not found on PATH — see Phase 7 |
| VS Code CLI | 1.127.0 | commit `4fe60c8b1cdac1c4c174f2fb180d0d758272d713` |
| ruff (global, `~/.local/bin`) | present | project will pin its own via uv regardless |
| mypy (global) | **not installed** | will be added as project dev dependency |
| pytest (global) | **not installed** | will be added as project dev dependency |
| shellcheck | **not installed** | needed before Phase 18 validation; requires `apt install shellcheck` (sudo) |
| pip / pip3 / pipx | present | system pip; project deps go through uv only |

## VS Code extensions currently installed

```
apertia.vscode-aider
bradlc.vscode-tailwindcss
charliermarsh.ruff
eamodio.gitlens
gruntfuggly.todo-tree
mechatroner.rainbow-csv
mhutchie.git-graph
ms-azuretools.vscode-containers
ms-azuretools.vscode-docker
ms-python.debugpy
ms-python.python
ms-python.vscode-pylance
ms-python.vscode-python-envs
ms-vscode-remote.remote-wsl
openai.chatgpt
qwtel.sqlite-viewer
rangav.vscode-thunder-client
wholroyd.jinja
```

Missing for this project: **Remote SSH**, **C/C++** (`ms-vscode.cpptools`), **ESP-IDF** (`espressif.esp-idf-extension`). To be installed in Phase 14 (extension install requires user-space `code --install-extension`, no sudo).

## ESP-IDF

- `~/esp` does not exist. No existing ESP-IDF installation detected.
- No `IDF_*` environment variables set.
- ESP-IDF build prerequisites **not installed**: `cmake`, `ninja`, `flex`, `bison`, `gperf`, `dfu-util`, `ccache` all missing from PATH. `libusb-1.0-0`/`-dev` not installed per dpkg.
- `python3-venv` and `python3-pip` ARE installed at the system level (3.12.3), which ESP-IDF's installer can use if needed, though the project's own Python tooling uses uv.
- These will require `sudo apt install` — approval will be requested before Phase 9 executes.

## dialout / serial

- Current groups for `bowen`: `bowen adm cdrom sudo dip plugdev users docker`
- **`bowen` is NOT in the `dialout` group.** The `dialout` group exists (gid 20) but has no members currently. Serial port access to ESP32 will fail until this is remedied.
- Action required (Phase 10, with approval): `sudo usermod -aG dialout bowen`, followed by a full WSL restart (`wsl --shutdown` from Windows) — group membership does not take effect in the current session or via `newgrp` alone.

## SSH

- OpenSSH client: `OpenSSH_9.6p1 Ubuntu-3ubuntu13.16, OpenSSL 3.0.13`
- `~/.ssh` exists with mode `700`, contains:
  - `id_ed25519` / `id_ed25519.pub` (created 2026-01-10)
  - `id_ed25519_new` / `id_ed25519_new.pub` (created 2026-04-24)
  - `authorized_keys`, `known_hosts`, `known_hosts.old`
  - `config` — **currently has three `Host github.com` stanzas** (one duplicate pair pointing at `id_ed25519_new`). This is pre-existing state, not something this setup created. It is left untouched; a backup will be taken before any edit in Phase 12, and only an idempotent `Host neurosync-pi` block will be appended.
- No existing `Host neurosync-pi` (or similar) entry — a new one will be added in Phase 12 rather than reusing an existing alias.
- No dedicated NeuroSync deploy key currently exists; Phase 12 will create `~/.ssh/id_ed25519_neurosync` only if needed.

## USB / ESP32

- `usbipd.exe` **not found** via WSL interop PATH. It is either not installed on the Windows side or not on the Windows `PATH` exposed to WSL. This must be installed/verified on the **Windows** side (outside WSL's control) before USB passthrough of the ESP32 will work — recorded as a manual action.
- No `/dev/ttyUSB*` or `/dev/ttyACM*` devices currently present (expected — no board attached/bound yet).

## Raspberry Pi

- `neurosync-pi.local` is **not currently resolvable/reachable** (`ping` failed: name not known). This is expected if the Pi is powered off, not on the network, or mDNS isn't resolving from WSL2 yet.
- Recorded as a blocker for Phase 12 bootstrap/deploy execution (scripts will still be generated per Phase 19 instructions; they will not be run).

## Existing project state

- `~/dev/projects/neurosync-pro` did not exist prior to this setup run except for a `docs/` directory created moments earlier in this same session to hold this audit file.
- No `.git` repository present — Phase 2 will run `git init` (never `git init` over an existing repo, and no destructive action needed since none exists).

## Existing global configuration (inspected, NOT modified)

- `~/.claude/settings.json` — exists (1520 bytes). Left untouched; this project uses its own `.claude/settings.json` (Phase 6).
- `~/.claude/CLAUDE.md` — exists (global user instructions). Left untouched.
- `~/.mcp.json` — exists, configures `memory`, `sequential-thinking`, and `alice` MCP servers globally. Left untouched.
- `~/.bashrc` — exists and already has multiple marked sections (`>>> armoury-dev-terminal <<<`, `>>> alice-stack-env <<<`) plus **exported secrets** (`OPENAI_API_KEY`, `GITHUB_TOKEN`) directly in the file. No `NEUROSYNC` marker present yet. **Note:** these secret values were observed in plaintext during this audit but are intentionally not reproduced here or elsewhere in the repo. Phase 16 will append its own idempotently-marked `neurosync` section without touching existing content, following the same backup-first convention already used by the `armoury-dev-terminal` marker.
- `~/bin/` — exists with several personal dev tools (`ai`, `devctl`, `cl`, `ccloud`, `claude-cloud`, `claude-local`, `newproject-ai`) plus timestamped `.bak.*` files following the same backup convention this setup will use. Nothing here will be modified; `~/bin/neurosync-idf` will be added in Phase 9 as a new file.

## Security note

While auditing `~/.bashrc`, live values for `OPENAI_API_KEY` and `GITHUB_TOKEN` were visible in plaintext in that file. This is pre-existing user configuration, not something introduced by this setup, and is out of scope to change — flagging only for awareness. No secret values are stored or repeated anywhere in the `neurosync-pro` repository.

## Summary of blockers for later phases

| Blocker | Affects | Resolution |
|---|---|---|
| `bowen` not in `dialout` | ESP32 serial access | `sudo usermod -aG dialout bowen` + WSL restart (needs approval) |
| ESP-IDF prerequisites not installed | Phase 9 | `sudo apt install` a defined package list (needs approval) |
| `shellcheck` not installed | Phase 18 validation | `sudo apt install shellcheck` (needs approval) |
| `usbipd.exe` not on WSL-visible PATH | Phase 10 | Manual action on Windows side |
| `neurosync-pi.local` unreachable | Phase 12 bootstrap/deploy | Manual action — verify Pi is powered/networked |
| Codex CLI not installed | Phase 7 | Official standalone installer (needs approval to fetch/run) |
