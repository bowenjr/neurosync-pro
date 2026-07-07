# ESP32 setup

Target: original ESP32-WROOM-32, IDF target `esp32`. Exact serial port is
discovered at connect time, never assumed.

## Status as of the initial setup run (2026-07-07)

- ESP-IDF **v5.5.4** (highest stable non-RC v5.x tag at the time) is cloned
  to `~/esp/esp-idf-5.5.4`, symlinked at `~/esp/esp-idf-current`.
- `~/esp/esp-idf-current/install.sh esp32` downloaded the Xtensa toolchain,
  GDB, and the ULP toolchain successfully, but **failed to complete** on
  `openocd-esp32` (missing system `libusb-1.0.so.0`) and therefore never
  created the Python virtual environment `idf.py` needs. See
  `manual-actions.md` for the exact fix.
- No ESP32 board was attached during setup, so no serial device was
  detected and firmware was not built or flashed.

## Finishing the toolchain install

```bash
sudo apt-get install -y libusb-1.0-0 libusb-1.0-0-dev flex bison gperf \
  cmake ninja-build ccache dfu-util libffi-dev libssl-dev shellcheck git wget
~/esp/esp-idf-current/install.sh esp32
make doctor   # should show ESP-IDF python env: PASS afterward
```

## Building (never flashes)

```bash
make esp32-build
```

Runs `idf.py -C firmware/esp32 set-target esp32` then `idf.py build`. The
firmware source (`firmware/esp32/main/`) never enables Wi-Fi, Bluetooth,
DAC, ADC, PWM, or haptic output, and forces `GPIO23` (output enable) plus
four placeholder output pins low as the very first thing `app_main` does —
see `firmware/esp32/main/nsp_board.h` and `nsp_safe_state.c`.

## Connecting a board (USB passthrough from Windows)

1. Plug the ESP32 into a USB port on the Windows host.
2. On **Windows**, in an Administrator PowerShell:
   ```powershell
   scripts\windows\esp32-usb-list.ps1
   scripts\windows\esp32-usb-bind.ps1 -BusId <busid-from-list>
   ```
3. On Windows (regular PowerShell is fine), after every reconnect/replug or
   WSL restart:
   ```powershell
   scripts\windows\esp32-usb-attach.ps1 -BusId <busid>
   ```
4. Back in WSL:
   ```bash
   scripts/esp32/detect.sh    # or: nsesp
   ```
   If `usermod -aG dialout` hasn't been applied and WSL restarted yet, the
   device node will exist but access will be denied — see
   `manual-actions.md`.

## Flashing (requires explicit approval every time)

```bash
make esp32-flash CONFIRM=YES
```

`scripts/esp32/flash.sh`: prints the Git commit, ESP-IDF version, target,
and detected port; refuses to flash a target other than `esp32`; refuses
to flash with uncommitted changes unless you also pass `FORCE_DIRTY=YES`; and
never erases flash. **Do not run this without the user's explicit
approval for that specific flash**, per `AGENTS.md`.

## Monitoring (never flashes)

```bash
make esp32-monitor
```
