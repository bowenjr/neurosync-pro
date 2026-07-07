"""Read-only discovery helpers: serial ports, Raspberry Pi identity, audio devices.

Nothing in this module opens a serial port for writing, enables a GPIO, or
otherwise changes hardware state — it only inspects and reports.
"""

from __future__ import annotations

import platform
import shutil
import subprocess
from dataclasses import dataclass

from serial.tools import list_ports


@dataclass(frozen=True)
class SerialPortInfo:
    device: str
    description: str
    vid: int | None
    pid: int | None
    serial_number: str | None
    manufacturer: str | None


def list_serial_ports() -> list[SerialPortInfo]:
    """Enumerate available serial ports. Does not open or write to any port."""
    return [
        SerialPortInfo(
            device=p.device,
            description=p.description or "",
            vid=p.vid,
            pid=p.pid,
            serial_number=p.serial_number,
            manufacturer=p.manufacturer,
        )
        for p in list_ports.comports()
    ]


@dataclass(frozen=True)
class PiIdentity:
    is_raspberry_pi: bool
    model: str | None
    os_release: str | None
    architecture: str
    python_version: str


def detect_pi_identity() -> PiIdentity:
    """Best-effort local identity check. Reports whether *this* host is a Pi.

    Safe to run on Armoury (will report `is_raspberry_pi=False`) or on the
    Raspberry Pi itself.
    """
    model_path = "/proc/device-tree/model"
    model: str | None = None
    try:
        with open(model_path, "rb") as fh:
            model = fh.read().split(b"\x00", 1)[0].decode("utf-8", errors="replace")
    except OSError:
        model = None

    os_release: str | None = None
    try:
        with open("/etc/os-release") as fh:
            os_release = fh.read()
    except OSError:
        os_release = None

    is_pi = model is not None and "raspberry pi" in model.lower()

    return PiIdentity(
        is_raspberry_pi=is_pi,
        model=model,
        os_release=os_release,
        architecture=platform.machine(),
        python_version=platform.python_version(),
    )


@dataclass(frozen=True)
class AudioDevice:
    card: str
    description: str


def list_audio_devices() -> list[AudioDevice]:
    """Best-effort ALSA device listing via `aplay -l`. Returns [] if unavailable.

    Does not configure, open, or play through any audio device.
    """
    aplay = shutil.which("aplay")
    if aplay is None:
        return []

    try:
        result = subprocess.run(
            [aplay, "-l"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []

    devices: list[AudioDevice] = []
    for line in result.stdout.splitlines():
        if line.startswith("card "):
            card, _, rest = line.partition(":")
            devices.append(AudioDevice(card=card.strip(), description=rest.strip()))
    return devices
