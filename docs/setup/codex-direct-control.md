# Direct Codex control via `make` targets

Codex (and Claude Code) should operate the Pi and ESP32 through the
`Makefile` targets rather than inventing equivalent one-off commands — the
targets encode the approval gates described in `AGENTS.md`.

## Safe targets (no confirmation required)

```
make doctor          # full environment health check, read-only
make lint typecheck test check
make pi-status        # Pi reachability + basic status
make pi-inventory      # print Pi inventory JSON; requires network access
make pi-test           # run unit tests on whatever is currently deployed
make pi-logs
make pi-shell           # interactive SSH shell on the Pi
make esp32-detect       # list candidate serial devices, read-only
make esp32-build        # idf.py build, never flashes
make esp32-chip-info    # read-only chip identification
make esp32-monitor       # serial monitor, never flashes
```

## Gated targets (require CONFIRM=YES)

```
make pi-bootstrap CONFIRM=YES
make pi-inventory-save CONFIRM=YES
make pi-deploy CONFIRM=YES [RESTART=YES]
make esp32-flash CONFIRM=YES [FORCE_DIRTY=YES]
make esp32-flash-monitor CONFIRM=YES [FORCE_DIRTY=YES]
```

`pi-inventory-save` writes `hardware/manifests/raspberry-pi.json`
atomically on Armoury. None of these erase flash, use `rsync --delete`, or
restart services beyond what's explicitly requested.

## Example Codex requests

- "Run `make doctor` and repair only setup failures."
- "Run `make pi-status` and summarize the Pi inventory."
- "Deploy the current committed build to the Pi. Show the exact rsync and
  remote commands and request approval before execution." — Codex should
  show the `make pi-deploy CONFIRM=YES` invocation and what it will run
  (`scripts/pi/deploy.sh`), and wait for you to say go before running it.
- "Build the ESP32 diagnostic firmware and report binary size." — `make
  esp32-build`, then report the `.bin` size from the build output.
- "Prepare to flash the ESP32. Verify target, port, firmware commit, and
  clean Git state. Do not flash until I approve." — Codex should run
  `scripts/esp32/detect.sh`, `git status`, `git rev-parse --short HEAD`,
  confirm the target is `esp32`, and then stop and ask before running
  `make esp32-flash CONFIRM=YES`.
