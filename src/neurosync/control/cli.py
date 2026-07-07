"""NeuroSync Pro CLI."""

from __future__ import annotations

import platform
import sys
from typing import Any

import typer
from rich.console import Console
from rich.table import Table

from neurosync.control.config import load_config
from neurosync.control.hardware_discovery import (
    detect_pi_identity,
    list_audio_devices,
    list_serial_ports,
)
from neurosync.control.serial_link import ControllerClient, SerialProtocolError

app = typer.Typer(help="NeuroSync Pro diagnostic CLI.")
console = Console()


@app.command()
def doctor() -> None:
    """Quick in-process health check: config resolution and module imports."""
    table = Table(title="neurosync doctor")
    table.add_column("Check")
    table.add_column("Result")

    table.add_row("Python", platform.python_version())

    try:
        cfg = load_config()
        table.add_row("Config resolved", "OK")
        table.add_row("  pi_host", cfg.pi_host)
        table.add_row("  esp32_target", cfg.esp32_target)
    except Exception as exc:  # noqa: BLE001 - report, don't crash the doctor
        table.add_row("Config resolved", f"FAIL: {exc}")

    try:
        ports = list_serial_ports()
        table.add_row("Serial enumeration", f"OK ({len(ports)} port(s))")
    except Exception as exc:  # noqa: BLE001
        table.add_row("Serial enumeration", f"FAIL: {exc}")

    console.print(table)


@app.command("pi-info")
def pi_info() -> None:
    """Report whether the current host is a Raspberry Pi, and basic identity."""
    identity = detect_pi_identity()
    table = Table(title="pi-info")
    table.add_column("Field")
    table.add_column("Value")
    table.add_row("Is Raspberry Pi", str(identity.is_raspberry_pi))
    table.add_row("Model", identity.model or "unknown")
    table.add_row("Architecture", identity.architecture)
    table.add_row("Python", identity.python_version)
    console.print(table)


@app.command("serial-list")
def serial_list() -> None:
    """List serial ports visible to this host. Read-only — opens nothing."""
    ports = list_serial_ports()
    if not ports:
        console.print("No serial ports detected.")
        return
    table = Table(title="serial-list")
    for col in ("Device", "Description", "VID:PID", "Serial", "Manufacturer"):
        table.add_column(col)
    for p in ports:
        vid_pid = f"{p.vid:04x}:{p.pid:04x}" if p.vid and p.pid else "-"
        table.add_row(
            p.device, p.description, vid_pid, p.serial_number or "-", p.manufacturer or "-"
        )
    console.print(table)


def _controller_client(port: str, timeout: float) -> ControllerClient:
    return ControllerClient(port=port, timeout=timeout)


def _print_controller_response(title: str, response: dict[str, Any]) -> None:
    table = Table(title=title)
    table.add_column("Field")
    table.add_column("Value")
    for key, value in response.items():
        if isinstance(value, dict):
            table.add_row(key, ", ".join(f"{k}={v}" for k, v in value.items()))
        else:
            table.add_row(key, str(value))
    console.print(table)


def _run_controller_command(command: str, port: str, timeout: float) -> None:
    client = _controller_client(port, timeout)
    try:
        if command == "hello":
            response = client.hello()
        elif command == "get_status":
            response = client.get_status()
        elif command == "heartbeat":
            response = client.heartbeat()
        else:
            raise RuntimeError(f"unsupported controller CLI command: {command}")
    except SerialProtocolError as exc:
        raise typer.BadParameter(str(exc)) from exc
    _print_controller_response(command, response)


@app.command("controller-hello")
def controller_hello(
    port: str = typer.Option(..., "--port", help="Serial device, e.g. /dev/ttyUSB0"),
    timeout: float = typer.Option(1.0, "--timeout", min=0.1, help="Read timeout in seconds"),
) -> None:
    """Send a safe hello request to the ESP32 controller."""
    _run_controller_command("hello", port, timeout)


@app.command("controller-status")
def controller_status(
    port: str = typer.Option(..., "--port", help="Serial device, e.g. /dev/ttyUSB0"),
    timeout: float = typer.Option(1.0, "--timeout", min=0.1, help="Read timeout in seconds"),
) -> None:
    """Read the ESP32 controller safe status."""
    _run_controller_command("get_status", port, timeout)


@app.command("controller-heartbeat")
def controller_heartbeat(
    port: str = typer.Option(..., "--port", help="Serial device, e.g. /dev/ttyUSB0"),
    timeout: float = typer.Option(1.0, "--timeout", min=0.1, help="Read timeout in seconds"),
) -> None:
    """Send one safe heartbeat request to the ESP32 controller."""
    _run_controller_command("heartbeat", port, timeout)


@app.command("audio-list")
def audio_list() -> None:
    """List ALSA audio devices via `aplay -l`. Read-only — plays nothing."""
    devices = list_audio_devices()
    if not devices:
        console.print("No audio devices detected (or `aplay` unavailable).")
        return
    table = Table(title="audio-list")
    table.add_column("Card")
    table.add_column("Description")
    for d in devices:
        table.add_row(d.card, d.description)
    console.print(table)


def main() -> None:
    app()


if __name__ == "__main__":
    main()
    sys.exit(0)
