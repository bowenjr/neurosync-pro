# Raspberry Pi 3 deviation notes

The deployment target for this project is a **Raspberry Pi 3**, not a
Raspberry Pi 5. This document exists so that assumptions don't quietly
drift toward Pi 5 capabilities.

## Why this matters

- **CPU**: Pi 3 is a quad-core Cortex-A53 @ ~1.2 GHz (BCM2837), materially
  slower than a Pi 5. Avoid workloads on the Pi that assume Pi 5-class
  headroom (e.g., heavy in-process signal processing) — prefer pushing
  timing-critical or compute-heavy work to the ESP32 or back to Armoury for
  offline analysis.
- **RAM**: Pi 3 tops out at 1 GB. Do not assume multi-GB working sets are
  available on the Pi; logging and buffering code should be written for a
  constrained-memory target and should flush/rotate rather than accumulate.
- **USB**: Pi 3 USB is shared with onboard Ethernet/USB hub silicon (single
  upstream USB channel on early revisions), so USB serial throughput and
  latency budgets should stay conservative.
- **No onboard Bluetooth/Wi-Fi assumptions beyond Pi 3's actual chip**: Pi 3
  has BCM43438 Wi-Fi/BT; don't assume Pi 5's newer radio or PCIe-attached
  peripherals.
- **No PCIe, no native power button, no Pi 5-only GPIO features.**
- **Python version**: this repo pins `requires-python = ">=3.11"` precisely
  because the Pi's OS-provided Python may lag behind whatever is newest on
  Armoury. Do not raise the floor without first confirming what the actual
  deployed Pi provides (`neurosync pi-info`, `scripts/pi/inventory.sh`).

## Practical implications for this repo

- Keep the Pi-side supervisory app's dependency footprint light. Heavy
  numerical/GUI dependencies are deliberately deferred (see Phase 4 of the
  setup) until there's a concrete need, and even then should be evaluated
  for Pi 3 viability before being added to the shared `pyproject.toml`.
- `scripts/pi/bootstrap.sh` detects and records the exact Pi model,
  OS, architecture, Python, storage, and memory into
  `hardware/manifests/raspberry-pi.json` — treat that file as the source of
  truth for what the real target actually is, rather than assuming Pi 3
  nominal specs.
