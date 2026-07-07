"""Thin, explicit wrapper and milestone-1 client for the ESP32.

This module only provides the mechanism for line-oriented request/response
over USB serial (discovery, configuration, arm/start/stop, heartbeat,
telemetry, fault reporting). It contains no protocol-specific arm/start
logic and enables nothing by import or instantiation alone — a connection
is only opened when `SerialLink.open()` (or the context manager) is called
explicitly by a caller.
"""

from __future__ import annotations

import json
from collections.abc import Callable
from types import TracebackType
from typing import Any, Protocol

import serial

PROTOCOL_VERSION = 1
DEFAULT_BAUDRATE = 115200
MAX_INPUT_LINE_LENGTH = 512


class SerialProtocolError(RuntimeError):
    """Base class for serial protocol failures."""


class SerialTimeoutError(SerialProtocolError):
    """No response arrived before the serial timeout."""


class SerialResponseError(SerialProtocolError):
    """The controller returned invalid or unsafe protocol data."""


class LineLink(Protocol):
    def open(self) -> None: ...
    def close(self) -> None: ...
    def write_line(self, line: str) -> None: ...
    def read_line(self) -> str | None: ...


class SerialLink:
    """Line-oriented serial connection. Caller controls open/close explicitly."""

    def __init__(self, port: str, baudrate: int = DEFAULT_BAUDRATE, timeout: float = 1.0) -> None:
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self._conn: serial.Serial | None = None

    def open(self) -> None:
        if self._conn is not None and self._conn.is_open:
            return
        self._conn = serial.Serial(
            port=self.port,
            baudrate=self.baudrate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=self.timeout,
        )
        self._conn.reset_input_buffer()
        self._conn.reset_output_buffer()

    def close(self) -> None:
        if self._conn is not None:
            self._conn.close()
            self._conn = None

    @property
    def is_open(self) -> bool:
        return self._conn is not None and self._conn.is_open

    def write_line(self, line: str) -> None:
        if self._conn is None or not self._conn.is_open:
            raise RuntimeError("SerialLink is not open; call open() first")
        self._conn.write((line.rstrip("\n") + "\n").encode("utf-8"))

    def read_line(self) -> str | None:
        if self._conn is None or not self._conn.is_open:
            raise RuntimeError("SerialLink is not open; call open() first")
        raw = self._conn.readline()
        if not raw:
            return None
        return raw.decode("utf-8", errors="replace").rstrip("\r\n")

    def __enter__(self) -> SerialLink:
        self.open()
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        tb: TracebackType | None,
    ) -> None:
        self.close()


class ControllerClient:
    """Milestone-1 discovery/status client for protocol-v1."""

    def __init__(
        self,
        port: str,
        *,
        baudrate: int = DEFAULT_BAUDRATE,
        timeout: float = 1.0,
        link_factory: Callable[[str, int, float], LineLink] | None = None,
    ) -> None:
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self._next_sequence = 1
        self._link_factory = link_factory or SerialLink

    def hello(self) -> dict[str, Any]:
        return self._request("hello")

    def get_status(self) -> dict[str, Any]:
        return self._request("get_status")

    def heartbeat(self) -> dict[str, Any]:
        return self._request("heartbeat")

    def _request(self, command: str) -> dict[str, Any]:
        sequence = self._next_sequence
        self._next_sequence += 1
        request = {
            "version": PROTOCOL_VERSION,
            "sequence": sequence,
            "command": command,
        }
        line = json.dumps(request, separators=(",", ":"))
        link = self._link_factory(self.port, self.baudrate, self.timeout)
        link.open()
        try:
            link.write_line(line)
            response_line = link.read_line()
        finally:
            link.close()
        if response_line is None:
            raise SerialTimeoutError(f"timed out waiting for {command} response on {self.port}")
        return validate_controller_response(response_line, sequence, command)


def validate_controller_response(line: str, sequence: int, command: str) -> dict[str, Any]:
    if len(line.encode("utf-8")) > MAX_INPUT_LINE_LENGTH:
        raise SerialResponseError("response line exceeded 512 bytes")
    try:
        response = json.loads(line)
    except json.JSONDecodeError as exc:
        raise SerialResponseError(f"invalid JSON response: {exc.msg}") from exc
    if not isinstance(response, dict):
        raise SerialResponseError("response JSON must be an object")
    if response.get("sequence") != sequence:
        raise SerialResponseError(
            f"sequence mismatch: expected {sequence}, got {response.get('sequence')!r}"
        )
    if response.get("status") != "ack":
        error = response.get("error", "unknown_error")
        raise SerialResponseError(f"controller returned NAK: {error}")
    if response.get("command") != command:
        raise SerialResponseError(
            f"command mismatch: expected {command}, got {response.get('command')!r}"
        )
    if response.get("state") != "SAFE":
        raise SerialResponseError(f"controller state is not SAFE: {response.get('state')!r}")
    if response.get("output_enable") is not False:
        raise SerialResponseError("controller reported output_enable true")
    return response
