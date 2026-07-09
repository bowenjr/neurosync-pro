from __future__ import annotations

import json
import os
import signal
import socket
import subprocess
import sys
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest

import neurosync.controller.daemon as daemon_module
from neurosync.control.serial_link import DEFAULT_BAUDRATE, SerialResponseError, SerialTimeoutError
from neurosync.controller.ipc import request as ipc_request
from neurosync.controller.ipc import serve_ipc
from neurosync.controller.service import ControllerDaemon, prepare_socket_path
from neurosync.controller.state import DaemonState


class ManualClock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now

    def sleep(self, seconds: float) -> None:
        self.now += seconds
        time.sleep(0)


def response_for(line: str, **overrides: Any) -> str:
    request = json.loads(line)
    command = request["command"]
    payload: dict[str, Any] = {
        "version": 1,
        "sequence": request["sequence"],
        "status": "ack",
        "command": command,
        "state": "SAFE",
        "output_enable": False,
    }
    if command == "hello":
        payload.update(
            {
                "device": "neurosync-esp32",
                "firmware_version": "0.1.0",
                "git_commit": "unknown",
                "esp_idf_version": "5.5.4",
                "chip_model": "ESP32",
                "chip_revision": 3,
                "capabilities": {
                    "configure": False,
                    "arm": False,
                    "start": False,
                    "dac": False,
                    "adc": False,
                    "pwm": False,
                },
            }
        )
    elif command == "get_status":
        payload.update({"uptime_ms": 100, "reset_reason": "power-on", "faults": 0})
    elif command == "heartbeat":
        payload.update({"uptime_ms": 200})
    payload.update(overrides)
    return json.dumps(payload, separators=(",", ":"))


class ScriptedLink:
    instances: list[ScriptedLink] = []

    def __init__(
        self,
        _port: str,
        _baudrate: int = DEFAULT_BAUDRATE,
        _read_timeout: float = 0.1,
        _write_timeout: float = 0.1,
        _startup_delay: float = 0.0,
        *,
        responder: Callable[[str], list[str | None]],
        clock: ManualClock,
    ) -> None:
        self.is_open = False
        self.writes: list[str] = []
        self.closed = False
        self._responder = responder
        self._clock = clock
        self._responses: list[str | None] = []
        ScriptedLink.instances.append(self)

    def open(self) -> None:
        self.is_open = True

    def close(self) -> None:
        self.closed = True
        self.is_open = False

    def prepare_for_request(self) -> None:
        return

    def write_line(self, line: str) -> None:
        self.writes.append(line)
        self._responses = self._responder(line)

    def read_line(self) -> str | None:
        if self._responses:
            return self._responses.pop(0)
        self._clock.sleep(0.05)
        return None


def make_daemon(
    responder: Callable[[str], list[str | None]],
    *,
    clock: ManualClock | None = None,
    heartbeat_interval: float = 0.2,
) -> ControllerDaemon:
    test_clock = clock or ManualClock()

    def factory(
        port: str, baudrate: int, read_timeout: float, write_timeout: float, startup_delay: float
    ) -> ScriptedLink:
        return ScriptedLink(
            port,
            baudrate,
            read_timeout,
            write_timeout,
            startup_delay,
            responder=responder,
            clock=test_clock,
        )

    return ControllerDaemon(
        serial_port="/dev/ttyUSB0",
        link_factory=factory,
        clock=test_clock,
        sleep=test_clock.sleep,
        startup_delay=0.0,
        request_timeout=0.2,
        heartbeat_interval=heartbeat_interval,
        backoff_sequence=(0.01, 0.02, 0.05, 0.1),
    )


def wait_for(predicate: Callable[[], bool], timeout: float = 1.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.005)
    raise AssertionError("condition was not met")


def wait_for_socket(socket_path: Path, timeout: float = 3.0) -> None:
    deadline = time.monotonic() + timeout
    last_error: OSError | None = None
    while time.monotonic() < deadline:
        if socket_path.exists():
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
                client.settimeout(0.1)
                try:
                    client.connect(str(socket_path))
                except OSError as exc:
                    last_error = exc
                else:
                    return
        time.sleep(0.01)
    raise AssertionError(f"daemon socket was not ready at {socket_path}: {last_error}")


def test_daemon_starts_with_no_esp32_and_reconnects_after_absence() -> None:
    attempts = 0

    def factory(
        _port: str,
        _baudrate: int,
        _read_timeout: float,
        _write_timeout: float,
        _startup_delay: float,
    ) -> ScriptedLink:
        nonlocal attempts
        attempts += 1
        raise OSError("missing device")

    daemon = ControllerDaemon(
        link_factory=factory,
        startup_delay=0.0,
        backoff_sequence=(0.01, 0.02, 0.05, 0.1),
    )
    daemon.start()
    try:
        wait_for(lambda: daemon.snapshot().reconnect_attempts >= 2)
        assert daemon.snapshot().daemon_state == DaemonState.DISCONNECTED
        assert attempts >= 2
    finally:
        daemon.stop()


def test_successful_hello_status_and_recurring_heartbeat() -> None:
    clock = ManualClock()

    def responder(line: str) -> list[str | None]:
        return [response_for(line)]

    daemon = make_daemon(responder, clock=clock, heartbeat_interval=0.1)
    daemon.start()
    try:
        wait_for(
            lambda: len(ScriptedLink.instances) > 0
            and len(ScriptedLink.instances[-1].writes) >= 5
        )
        snapshot = daemon.snapshot()
        assert snapshot.daemon_state == DaemonState.SAFE
        assert snapshot.controller_connected is True
        assert snapshot.controller_state == "SAFE"
        assert snapshot.output_enable is False
        commands = [json.loads(line)["command"] for line in ScriptedLink.instances[-1].writes]
        assert commands[:2] == ["hello", "get_status"]
        assert commands.count("heartbeat") >= 3
    finally:
        daemon.stop()


def test_heartbeat_timeout_and_two_failure_disconnect_threshold() -> None:
    heartbeat_count = 0

    def responder(line: str) -> list[str | None]:
        nonlocal heartbeat_count
        command = json.loads(line)["command"]
        if command == "heartbeat":
            heartbeat_count += 1
            return []
        return [response_for(line)]

    daemon = make_daemon(responder, heartbeat_interval=0.1)

    with pytest.raises(SerialTimeoutError, match="heartbeat failure threshold"):
        daemon._connect_and_run()
    assert heartbeat_count == 2


def test_reconnect_backoff_sequence() -> None:
    clock = ManualClock()
    slept: list[float] = []

    def factory(
        _port: str,
        _baudrate: int,
        _read_timeout: float,
        _write_timeout: float,
        _startup_delay: float,
    ) -> ScriptedLink:
        raise OSError("missing device")

    def sleep(seconds: float) -> None:
        slept.append(seconds)
        clock.sleep(seconds)
        time.sleep(0)

    daemon = ControllerDaemon(
        link_factory=factory,
        startup_delay=0.0,
        backoff_sequence=(0.01, 0.02, 0.05, 0.1),
        clock=clock,
        sleep=sleep,
    )
    daemon.start()
    try:
        wait_for(lambda: daemon.snapshot().reconnect_attempts >= 4)
    finally:
        daemon.stop()
    assert slept[:4] == pytest.approx([0.01, 0.02, 0.05, 0.1], abs=0.005)


def test_sequence_mismatch_unsafe_state_and_output_enable_are_rejected() -> None:
    cases = [
        ({"sequence": 99}, "sequence mismatch"),
        ({"state": "RUNNING"}, "not SAFE"),
        ({"output_enable": True}, "output_enable true"),
    ]
    for overrides, message in cases:
        daemon = make_daemon(lambda line, o=overrides: [response_for(line, **o)])
        link = daemon._link_factory("/dev/null", DEFAULT_BAUDRATE, 0.1, 0.1, 0.0)
        link.open()
        with pytest.raises(SerialResponseError, match=message):
            daemon._request(link, "hello")


def test_non_json_serial_log_lines_are_ignored() -> None:
    daemon = make_daemon(lambda line: ["rst:0x1 boot log", "{not json", response_for(line)])
    link = daemon._link_factory("/dev/null", DEFAULT_BAUDRATE, 0.1, 0.1, 0.0)
    link.open()

    response = daemon._request(link, "hello")

    assert response["command"] == "hello"


def test_force_reconnect_closes_current_link() -> None:
    daemon = make_daemon(lambda line: [response_for(line)])
    link = daemon._link_factory("/dev/null", DEFAULT_BAUDRATE, 0.1, 0.1, 0.0)
    daemon._link = link
    link.open()

    daemon.force_reconnect()

    assert link.closed is True


def test_graceful_sigterm_shutdown(tmp_path: Path) -> None:
    socket_path = tmp_path / "controller.sock"
    code = (
        "from neurosync.controller.daemon import run_daemon;"
        f"run_daemon(serial_port='/dev/neurosync-missing', socket_path={str(socket_path)!r})"
    )
    proc = subprocess.Popen([sys.executable, "-c", code])
    try:
        wait_for_socket(socket_path)
        proc.send_signal(signal.SIGTERM)
        proc.wait(timeout=3)
        assert proc.returncode == 0
        assert not socket_path.exists()
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait(timeout=3)


def test_signal_handler_is_installed_before_daemon_initialization(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    events: list[str] = []

    class FakeDaemon:
        def __init__(self, *, serial_port: str, socket_path: str) -> None:
            events.append(f"init:{serial_port}:{socket_path}")
            os.kill(os.getpid(), signal.SIGTERM)

        def start(self) -> None:
            events.append("start")

        def stop(self) -> None:
            events.append("stop")

    class FakeServer:
        def handle_request(self) -> None:
            events.append("handle_request")

        def server_close(self) -> None:
            events.append("server_close")

    def fake_serve_ipc(_daemon: FakeDaemon, _socket_path: str) -> FakeServer:
        events.append("serve_ipc")
        return FakeServer()

    monkeypatch.setattr(daemon_module, "ControllerDaemon", FakeDaemon)
    monkeypatch.setattr(daemon_module, "serve_ipc", fake_serve_ipc)

    daemon_module.run_daemon(
        serial_port="/dev/neurosync-missing",
        socket_path=str(tmp_path / "controller.sock"),
    )

    assert events == [
        f"init:/dev/neurosync-missing:{tmp_path / 'controller.sock'}",
        "serve_ipc",
        "stop",
        "server_close",
    ]


def test_stale_socket_cleanup(tmp_path: Path) -> None:
    socket_path = tmp_path / "controller.sock"
    stale = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    stale.bind(str(socket_path))
    stale.close()

    prepare_socket_path(str(socket_path))

    assert not socket_path.exists()


def test_unix_socket_request_response_multiple_clients_and_no_passthrough(tmp_path: Path) -> None:
    daemon = make_daemon(lambda line: [response_for(line)])
    link = daemon._link_factory("/dev/null", DEFAULT_BAUDRATE, 0.1, 0.1, 0.0)
    link.open()
    daemon._link = link
    socket_path = tmp_path / "controller.sock"
    server = serve_ipc(daemon, str(socket_path))
    try:
        import threading

        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        first = ipc_request("ping", socket_path=str(socket_path), request_id=1)
        second = ipc_request("get_controller_status", socket_path=str(socket_path), request_id=2)
        assert first["status"] == "ack"
        assert first["pong"] is True
        assert second["status"] == "ack"
        reconnect = ipc_request("force_reconnect", socket_path=str(socket_path), request_id=3)
        assert reconnect["status"] == "ack"
        assert link.closed is True

        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.connect(str(socket_path))
            client.sendall(
                b'{"version":1,"request_id":4,"command":"configure","payload":{}}\n'
            )
            raw = client.recv(4096)
        rejected = json.loads(raw.decode("utf-8"))
        assert rejected["status"] == "nak"
        assert "unsupported command" in rejected["error"]
    finally:
        server.shutdown()
        server.server_close()
        if socket_path.exists():
            os.unlink(socket_path)
