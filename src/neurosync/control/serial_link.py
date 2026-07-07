"""Thin, explicit wrapper around a pyserial connection to the ESP32.

This module only provides the mechanism for line-oriented request/response
over USB serial (discovery, configuration, arm/start/stop, heartbeat,
telemetry, fault reporting). It contains no protocol-specific arm/start
logic and enables nothing by import or instantiation alone — a connection
is only opened when `SerialLink.open()` (or the context manager) is called
explicitly by a caller.
"""

from __future__ import annotations

from types import TracebackType

import serial


class SerialLink:
    """Line-oriented serial connection. Caller controls open/close explicitly."""

    def __init__(self, port: str, baudrate: int = 115200, timeout: float = 1.0) -> None:
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
            timeout=self.timeout,
        )

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
