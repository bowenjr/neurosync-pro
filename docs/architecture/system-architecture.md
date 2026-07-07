# System Architecture

## Three roles

```
┌─────────────┐      builds/deploys      ┌──────────────────┐      USB serial      ┌───────────┐
│   Armoury   │ ───────────────────────► │ Raspberry Pi 3    │ ◄──────────────────► │  ESP32    │
│ (authoritative)                        │ "neurosync-pi"    │   (protocol-v1)      │ (esp32)   │
└─────────────┘                          └──────────────────┘                      └───────────┘
```

**Armoury** is the only place source code is authored. It builds the Python
supervisory application, builds the ESP32 firmware image, and holds every
document and test in this repository. Nothing is ever edited only on the Pi
or only on the ESP32.

**Raspberry Pi 3** (`neurosync-pi`) runs the supervisory application:
session orchestration, configuration, PiFi audio output, logging of
synthetic/measured data, and (eventually) a touchscreen HMI. It talks to
the ESP32 over USB serial using `protocol-v1` (see
`docs/protocol/protocol-v1.md`). It does not implement timing-critical
control itself — that is the ESP32's job.

**ESP32** (ESP32-WROOM-32, IDF target `esp32`) owns everything that must be
deterministic: MCPWM generation, DAC/ADC sampling, the output state
machine, output gating (including the hard `GPIO23` output-enable line),
watchdogs, heartbeat supervision, and fault shutdown. It runs
Wi-Fi-and-Bluetooth-free, so its only extra-chip communication channel is
the USB serial link to the Pi.

Milestone 1 of that link is safe discovery/status only: UART0 over the
CP2102 bridge at 115200 8N1, newline-delimited JSON, and only `hello`,
`get_status`, and `heartbeat`. These commands report `SAFE` and
`output_enable: false`; they do not configure or energize any output.

## Why USB serial is a control channel, not a data-rate channel

The Pi-to-ESP32 link is used for discovery, configuration, arm/start/stop,
heartbeat, telemetry, and fault reporting. It is explicitly **not** used to
drive individual output edges: **a USB packet arriving must never generate
an individual 40 Hz edge or an individual DAC sample.** All time-critical
generation happens inside the ESP32 based on parameters it was configured
with, driven by its own hardware timers/MCPWM peripherals — never by the
arrival of a serial packet. This keeps timing correct even if the USB link
stalls, and keeps a slow/blocked Pi from ever being able to directly pulse
an output.

## Safe-state guarantee

On every boot and on every fault, the ESP32 firmware forces all outputs to
a safe state before doing anything else (see
`firmware/esp32/main/nsp_safe_state.c`). The Pi supervisory app never
assumes an output is off — it queries and displays the state the ESP32
reports, and the ESP32 is the sole authority on whether an output is
active.

Firmware can only enforce this after the application starts executing. The
physical output-enable circuit for `GPIO23` must therefore include an
external default-off pull network that holds the output-enable line disabled
before and during ESP32 reset and bootloader execution. No binding resistor
value exists in this repository yet; hardware design must record the chosen
value here before bring-up.

## Terminations

Every ESP32 output in this project is bench-instrumented: dummy loads,
optical fixtures, line-level loads, or fixed mechanical fixtures. There is
no biological load anywhere in the system, by design and by policy — see
`AGENTS.md`.
