# Manual actions required

Only actions that genuinely require you — not things an agent could safely
do unattended. Ordered roughly by what unblocks the most.

## 1. Install ESP-IDF / shellcheck build prerequisites (sudo, needs your password)

```bash
sudo apt-get update && sudo apt-get install -y \
  git wget flex bison gperf cmake ninja-build ccache \
  libffi-dev libssl-dev dfu-util libusb-1.0-0 libusb-1.0-0-dev \
  shellcheck
```

Then finish the ESP-IDF install (safe to re-run; skips what's already
downloaded):

```bash
~/esp/esp-idf-current/install.sh esp32
```

**Why this is manual:** `sudo` requires an interactive password prompt
that automated tooling in this session cannot supply, and passwordless
sudo was explicitly disallowed for this setup.

## 2. Add yourself to the `dialout` group, then restart WSL

```bash
sudo usermod -aG dialout bowen
```

Then, from **Windows** (not inside WSL):

```powershell
wsl --shutdown
```

...and reopen your WSL terminal. Group membership changes don't take
effect in the current session or via `newgrp` alone.

**Why this is manual:** requires `sudo` (see above) and a full WSL restart
that would drop this session.

## 3. Install usbipd-win on Windows

`usbipd.exe` was not found via WSL interop during setup, meaning either
it isn't installed on the Windows side or isn't on the Windows `PATH`.
Install it from <https://github.com/dorssel/usbipd-win> on **Windows**
(not WSL). This is required before `scripts/windows/esp32-usb-*.ps1` can
do anything.

## 4. Bind and attach the ESP32 over USB (once usbipd is installed)

From an **Administrator** PowerShell on Windows, once the ESP32 is
plugged in:

```powershell
scripts\windows\esp32-usb-list.ps1
scripts\windows\esp32-usb-bind.ps1 -BusId <busid>      # one-time per port
scripts\windows\esp32-usb-attach.ps1 -BusId <busid>    # every reconnect/replug/WSL-restart
```

**Why this is manual:** requires Administrator privileges on Windows and a
physical device to be present; the script deliberately does not guess a
BUSID.

## 5. Authorize the dedicated SSH key on the Raspberry Pi

`neurosync-pi.local` was not reachable during setup, so `ssh-copy-id` was
not attempted. Once the Pi is powered on and networked:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_neurosync.pub bowen@neurosync-pi.local
```

This will prompt for the Pi's password interactively.

**Why this is manual:** requires an interactive password and a reachable
Pi, neither of which was available during this setup run.

## 6. Codex trust prompt

The first time you run `codex` inside this repository, it may ask you to
trust the folder. Approve it once; this is a one-time, per-machine
prompt.

## 7. Confirm exact touchscreen and PiFi board identity

Not configured or probed during this setup (explicitly out of scope — see
the constraints given for this setup task). When you're ready to wire
these up, identify:

- Exact touchscreen model/interface (SPI/DSI/HDMI, resolution, driver).
- Exact PiFi board model/revision and its required Pi audio configuration.

Both require someone to physically inspect the hardware; this cannot be
inferred from Armoury.

## 8. ESP32 flashing approval

`scripts/esp32/flash.sh` / `make esp32-flash CONFIRM=YES` is ready but was
**not run** — no board was attached, and flashing always requires your
explicit approval for that specific flash regardless. See
`docs/setup/esp32-setup.md`.

## 9. Raspberry Pi bootstrap/deploy approval

`make pi-bootstrap CONFIRM=YES` and `make pi-deploy CONFIRM=YES` are ready
but were **not run** — the Pi was unreachable, and both require your
explicit approval regardless. See `docs/setup/raspberry-pi-setup.md`.
