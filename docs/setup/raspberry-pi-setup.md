# Raspberry Pi setup

Target: **Raspberry Pi 3**, SSH alias `neurosync-pi`, current alias address
`10.0.0.127`, user `bowen`, app path
`/home/bowen/apps/neurosync-pro`.

## Status as of the initial setup run (2026-07-07)

`neurosync-pi.local` was **not reachable** from Armoury during setup. All
scripts below were created and are ready to use, but none of the
Pi-touching steps (`bootstrap.sh`, `deploy.sh`, `install-services.sh`) were
executed. See `manual-actions.md`.

## One-time setup, once the Pi is reachable

1. Confirm reachability: `make pi-status` (or `nspi`).
2. If SSH key auth isn't set up yet, copy the dedicated NeuroSync key:
   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519_neurosync.pub bowen@neurosync-pi.local
   ```
   This requires typing the Pi's password interactively — it is not
   something this setup can do unattended. See `manual-actions.md`.
3. Bootstrap the Pi (installs packages, creates the app directory, installs
   `uv`):
   ```bash
   make pi-bootstrap CONFIRM=YES
   ```
   This refuses to run against anything that doesn't identify as a
   Raspberry Pi, and never touches `/boot` or audio configuration.
4. Deploy the current committed state:
   ```bash
   make pi-deploy CONFIRM=YES
   ```
   Uses `rsync` without `--delete`, runs `uv sync --locked` remotely, then
   runs the remote unit test suite. Does not restart any service unless you
   also pass `RESTART=YES` — and there's nothing to restart until
   `install-services.sh` has been run deliberately, later, once real
   application entry points exist.

## Day-to-day

```bash
make pi-status      # reachability + basic status, read-only
make pi-inventory     # print inventory JSON; read-only, requires network access
make pi-inventory-save CONFIRM=YES  # atomically write hardware/manifests/raspberry-pi.json
make pi-test          # run unit tests against what's currently deployed
make pi-logs
make pi-shell          # interactive SSH shell
```

## Persistent controller daemon

Milestone 2 adds one persistent Raspberry Pi controller daemon. It owns
`/dev/ttyUSB0`, keeps the ESP32 in `SAFE`, and exposes local status through
newline-delimited JSON on `/run/neurosync/controller.sock`. The future HMI
must use this Unix socket rather than opening the ESP32 serial device.

Installation and service lifecycle are explicit:

```bash
make pi-controller-install CONFIRM=YES
make pi-controller-start CONFIRM=YES
make pi-controller-status
make pi-controller-test
make pi-controller-logs
make pi-controller-stop CONFIRM=YES
make pi-controller-restart CONFIRM=YES
```

No HMI service is installed or enabled by these targets.

## PiFi audio / touchscreen HMI / GPIO outputs

Explicitly out of scope for this setup run — not configured, not enabled.
See `AGENTS.md` and the constraints given for this setup task.
