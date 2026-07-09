"""Persistent controller daemon service logic."""

from __future__ import annotations

import json
import os
import threading
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any

import serial

from neurosync.control.serial_link import (
    DEFAULT_BAUDRATE,
    DEFAULT_STARTUP_DELAY,
    LineLink,
    SerialLink,
    SerialProtocolError,
    SerialResponseError,
    SerialTimeoutError,
    parse_controller_response,
    validate_controller_response_object,
)
from neurosync.controller.state import ControllerSnapshot, DaemonState

DEFAULT_SERIAL_PORT = "/dev/ttyUSB0"
DEFAULT_SOCKET_PATH = "/run/neurosync/controller.sock"
READ_TIMEOUT_S = 0.5
WRITE_TIMEOUT_S = 0.5
REQUEST_TIMEOUT_S = 1.0
HEARTBEAT_INTERVAL_S = 1.0
HEARTBEAT_FAILURE_THRESHOLD = 2
RECONNECT_BACKOFF_S = (1.0, 2.0, 5.0, 10.0)


def default_link_factory(
    port: str, baudrate: int, read_timeout: float, write_timeout: float, startup_delay: float
) -> LineLink:
    return SerialLink(
        port,
        baudrate=baudrate,
        timeout=read_timeout,
        write_timeout=write_timeout,
        startup_delay=startup_delay,
    )


class ControllerDaemon:
    """Owns the ESP32 serial port and exposes safe local status snapshots."""

    def __init__(
        self,
        *,
        serial_port: str = DEFAULT_SERIAL_PORT,
        socket_path: str = DEFAULT_SOCKET_PATH,
        baudrate: int = DEFAULT_BAUDRATE,
        read_timeout: float = READ_TIMEOUT_S,
        write_timeout: float = WRITE_TIMEOUT_S,
        request_timeout: float = REQUEST_TIMEOUT_S,
        heartbeat_interval: float = HEARTBEAT_INTERVAL_S,
        startup_delay: float = DEFAULT_STARTUP_DELAY,
        backoff_sequence: tuple[float, ...] = RECONNECT_BACKOFF_S,
        link_factory: Callable[[str, int, float, float, float], LineLink] = default_link_factory,
        clock: Callable[[], float] = time.monotonic,
        sleep: Callable[[float], None] = time.sleep,
    ) -> None:
        self.serial_port = serial_port
        self.socket_path = socket_path
        self.baudrate = baudrate
        self.read_timeout = read_timeout
        self.write_timeout = write_timeout
        self.request_timeout = request_timeout
        self.heartbeat_interval = heartbeat_interval
        self.startup_delay = startup_delay
        self.backoff_sequence = backoff_sequence
        self._link_factory = link_factory
        self._clock = clock
        self._sleep = sleep
        self._stop_event = threading.Event()
        self._force_reconnect = threading.Event()
        self._lock = threading.Lock()
        self._snapshot = ControllerSnapshot(serial_port=serial_port)
        self._worker: threading.Thread | None = None
        self._link: LineLink | None = None
        self._next_sequence = 1

    def start(self) -> None:
        if self._worker is not None and self._worker.is_alive():
            return
        self._stop_event.clear()
        self._worker = threading.Thread(
            target=self._serial_worker, name="controller-serial", daemon=True
        )
        self._worker.start()

    def stop(self) -> None:
        self._set_snapshot(daemon_state=DaemonState.STOPPING, controller_connected=False)
        self._stop_event.set()
        self._force_reconnect.set()
        self._close_link()
        if self._worker is not None:
            self._worker.join(timeout=3.0)

    def force_reconnect(self) -> None:
        self._force_reconnect.set()
        self._close_link()

    def snapshot(self) -> ControllerSnapshot:
        with self._lock:
            return self._snapshot

    def handle_command(self, command: str) -> dict[str, Any]:
        snapshot = self.snapshot()
        if command == "ping":
            return {"pong": True}
        if command == "force_reconnect":
            self.force_reconnect()
            return {"force_reconnect": "scheduled"}
        if command == "get_daemon_status":
            return self._daemon_payload(snapshot)
        if command == "get_controller_status":
            return self._controller_status_payload(snapshot)
        if command == "get_controller_identity":
            return {
                "daemon_state": snapshot.daemon_state.value,
                "controller_connected": snapshot.controller_connected,
                "identity": snapshot.identity,
                "serial_port": snapshot.serial_port,
            }
        raise ValueError("unsupported command")

    def _serial_worker(self) -> None:
        backoff_index = 0
        self._set_snapshot(daemon_state=DaemonState.DISCONNECTED, controller_connected=False)
        while not self._stop_event.is_set():
            self._set_snapshot(daemon_state=DaemonState.CONNECTING, next_reconnect_delay_s=None)
            try:
                self._connect_and_run()
                backoff_index = 0
            except Exception as exc:  # noqa: BLE001 - daemon must keep reconnecting
                state = (
                    DaemonState.FAULT
                    if isinstance(exc, SerialResponseError)
                    else DaemonState.DISCONNECTED
                )
                delay = self.backoff_sequence[min(backoff_index, len(self.backoff_sequence) - 1)]
                backoff_index += 1
                self._set_snapshot(
                    daemon_state=state,
                    controller_connected=False,
                    controller_state=None,
                    output_enable=None,
                    last_error=str(exc),
                    reconnect_attempts=self.snapshot().reconnect_attempts + 1,
                    next_reconnect_delay_s=delay,
                )
                self._close_link()
                self._sleep_interruptibly(delay)
        self._close_link()
        self._set_snapshot(daemon_state=DaemonState.STOPPING, controller_connected=False)

    def _connect_and_run(self) -> None:
        link = self._link_factory(
            self.serial_port,
            self.baudrate,
            self.read_timeout,
            self.write_timeout,
            self.startup_delay,
        )
        self._link = link
        link.open()
        link.prepare_for_request()

        identity = self._request(link, "hello")
        status = self._request(link, "get_status")
        self._set_safe_snapshot(identity=identity, status=status, last_heartbeat_monotonic=None)

        heartbeat_failures = 0
        while not self._stop_event.is_set():
            if self._force_reconnect.is_set():
                self._force_reconnect.clear()
                raise SerialTimeoutError("forced reconnect requested")
            if self._sleep_interruptibly(self.heartbeat_interval):
                break
            try:
                heartbeat = self._request(link, "heartbeat")
            except SerialResponseError:
                raise
            except SerialProtocolError as exc:
                heartbeat_failures += 1
                self._set_snapshot(
                    daemon_state=DaemonState.DEGRADED,
                    controller_connected=True,
                    last_error=str(exc),
                )
                if heartbeat_failures >= HEARTBEAT_FAILURE_THRESHOLD:
                    raise SerialTimeoutError("heartbeat failure threshold exceeded") from exc
                continue
            heartbeat_failures = 0
            self._set_safe_snapshot(status=heartbeat, last_heartbeat_monotonic=self._clock())

    def _request(self, link: LineLink, command: str) -> dict[str, Any]:
        sequence = self._next_sequence
        self._next_sequence += 1
        request = {"version": 1, "sequence": sequence, "command": command}
        link.write_line(json.dumps(request, separators=(",", ":")))
        deadline = self._clock() + self.request_timeout
        while self._clock() < deadline and not self._stop_event.is_set():
            response_line = link.read_line()
            if response_line is None:
                continue
            try:
                response = parse_controller_response(response_line)
            except SerialResponseError:
                continue
            return validate_controller_response_object(response, sequence, command)
        raise SerialTimeoutError(f"timed out waiting for {command} response on {self.serial_port}")

    def _set_safe_snapshot(
        self,
        *,
        identity: dict[str, Any] | None = None,
        status: dict[str, Any],
        last_heartbeat_monotonic: float | None,
    ) -> None:
        changes: dict[str, Any] = {
            "daemon_state": DaemonState.SAFE,
            "controller_connected": True,
            "controller_state": status.get("state", "SAFE"),
            "output_enable": status.get("output_enable"),
            "status": status,
            "last_heartbeat_monotonic": last_heartbeat_monotonic,
            "last_error": None,
            "next_reconnect_delay_s": None,
        }
        if identity is not None:
            changes["identity"] = identity
        self._set_snapshot(**changes)

    def _set_snapshot(self, **changes: Any) -> None:
        with self._lock:
            data = self._snapshot.__dict__.copy()
            data.update(changes)
            self._snapshot = ControllerSnapshot(**data)

    def _daemon_payload(self, snapshot: ControllerSnapshot) -> dict[str, Any]:
        return {
            "daemon_state": snapshot.daemon_state.value,
            "controller_connected": snapshot.controller_connected,
            "serial_port": snapshot.serial_port,
            "last_error": snapshot.last_error,
            "reconnect_attempts": snapshot.reconnect_attempts,
            "next_reconnect_delay_s": snapshot.next_reconnect_delay_s,
        }

    def _controller_status_payload(self, snapshot: ControllerSnapshot) -> dict[str, Any]:
        return {
            "daemon_state": snapshot.daemon_state.value,
            "controller_connected": snapshot.controller_connected,
            "controller_state": snapshot.controller_state,
            "output_enable": snapshot.output_enable,
            "last_heartbeat_age_ms": snapshot.heartbeat_age_ms(self._clock()),
            "serial_port": snapshot.serial_port,
            "last_error": snapshot.last_error,
        }

    def _sleep_interruptibly(self, seconds: float) -> bool:
        deadline = self._clock() + seconds
        while not self._stop_event.is_set() and self._clock() < deadline:
            remaining = max(0.0, deadline - self._clock())
            self._sleep(min(0.1, remaining))
        return self._stop_event.is_set()

    def _close_link(self) -> None:
        link = self._link
        self._link = None
        if link is not None:
            try:
                link.close()
            except (OSError, serial.SerialException):
                pass


def prepare_socket_path(socket_path: str) -> None:
    path = Path(socket_path)
    if not path.exists():
        return
    if not path.is_socket():
        raise RuntimeError(f"refusing to remove non-socket path: {socket_path}")
    try:
        import socket

        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as probe:
            probe.settimeout(0.1)
            probe.connect(socket_path)
    except OSError:
        os.unlink(socket_path)
    else:
        raise RuntimeError(f"controller socket is already active: {socket_path}")
