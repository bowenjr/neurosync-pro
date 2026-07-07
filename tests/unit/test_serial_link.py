from __future__ import annotations

import json
from collections.abc import Callable
from typing import Any

import pytest

import neurosync.control.serial_link as serial_link
from neurosync.control.serial_link import (
    DEFAULT_BAUDRATE,
    ControllerClient,
    SerialLink,
    SerialResponseError,
    SerialTimeoutError,
    validate_controller_response,
)


class ManualClock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now

    def advance(self, seconds: float) -> None:
        self.now += seconds


class SoftwareSerialSimulator:
    """In-memory serial peer for protocol-v1 client tests."""

    def __init__(
        self,
        _port: str,
        _baudrate: int = DEFAULT_BAUDRATE,
        _timeout: float = 1.0,
        startup_delay: float = 0.0,
        *,
        responder: Callable[[str], list[str | None]] | None = None,
        clock: ManualClock | None = None,
    ) -> None:
        self.is_open = False
        self.startup_delay = startup_delay
        self.prepare_count = 0
        self.writes: list[str] = []
        self._responses: list[str | None] = []
        self._responder = responder or self._default_responder
        self._clock = clock

    def open(self) -> None:
        self.is_open = True

    def close(self) -> None:
        self.is_open = False

    def prepare_for_request(self) -> None:
        self.prepare_count += 1
        if self._clock is not None:
            self._clock.advance(self.startup_delay)

    def write_line(self, line: str) -> None:
        self.writes.append(line)
        self._responses = self._responder(line)

    def read_line(self) -> str | None:
        if self._responses:
            return self._responses.pop(0)
        if self._clock is not None:
            self._clock.advance(0.2)
        return None

    @staticmethod
    def _default_responder(line: str) -> list[str]:
        request = json.loads(line)
        command = request["command"]
        response: dict[str, Any] = {
            "version": 1,
            "sequence": request["sequence"],
            "status": "ack",
            "command": command,
            "state": "SAFE",
            "output_enable": False,
        }
        if command == "hello":
            response.update(
                {
                    "device": "neurosync-esp32",
                    "firmware_version": "0.1.0",
                    "git_commit": "unknown",
                    "esp_idf_version": "5.4.0",
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
            response.update({"uptime_ms": 1234, "reset_reason": "power-on", "faults": 0})
        elif command == "heartbeat":
            response.update({"uptime_ms": 1234})
        else:
            return [
                json.dumps(
                    {
                        "version": 1,
                        "sequence": request["sequence"],
                        "status": "nak",
                        "error": "unknown_command",
                    },
                    separators=(",", ":"),
                )
            ]
        return [json.dumps(response, separators=(",", ":"))]


def make_client(
    responder: Callable[[str], list[str | None]] | None = None,
    *,
    timeout: float = 1.0,
    startup_delay: float = 0.0,
    clock: ManualClock | None = None,
) -> tuple[ControllerClient, list[SoftwareSerialSimulator]]:
    links: list[SoftwareSerialSimulator] = []
    test_clock = clock or ManualClock()

    def link_factory(
        port: str, baudrate: int, link_timeout: float, link_startup_delay: float
    ) -> SoftwareSerialSimulator:
        link = SoftwareSerialSimulator(
            port,
            baudrate,
            link_timeout,
            link_startup_delay,
            responder=responder,
            clock=test_clock,
        )
        links.append(link)
        return link

    return (
        ControllerClient(
            "/dev/null",
            timeout=timeout,
            startup_delay=startup_delay,
            clock=test_clock,
            link_factory=link_factory,
        ),
        links,
    )


def test_serial_link_configures_lines_before_open_and_delays_before_flush(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    events: list[str] = []

    class FakePySerial:
        def __init__(self) -> None:
            self.is_open = False
            events.append("construct_closed")

        def open(self) -> None:
            assert self.port == "/dev/ttyUSB0"
            assert self.baudrate == DEFAULT_BAUDRATE
            assert self.timeout == 1.5
            assert self.dtr is False
            assert self.rts is False
            events.append("open")
            self.is_open = True

        def close(self) -> None:
            events.append("close")
            self.is_open = False

        def reset_input_buffer(self) -> None:
            events.append("reset_input")

        def write(self, _data: bytes) -> int:
            return 0

        def readline(self) -> bytes:
            return b""

    monkeypatch.setattr(serial_link.serial, "Serial", FakePySerial)

    link = SerialLink(
        "/dev/ttyUSB0",
        timeout=1.5,
        startup_delay=2.0,
        sleep_func=lambda seconds: events.append(f"sleep:{seconds}"),
    )

    link.open()
    link.prepare_for_request()
    link.close()

    assert events == ["construct_closed", "open", "sleep:2.0", "reset_input", "close"]


def test_valid_hello_response() -> None:
    client, links = make_client()

    response = client.hello()

    assert response["command"] == "hello"
    assert response["state"] == "SAFE"
    assert response["output_enable"] is False
    assert response["capabilities"] == {
        "configure": False,
        "arm": False,
        "start": False,
        "dac": False,
        "adc": False,
        "pwm": False,
    }
    assert links[0].writes == ['{"version":1,"sequence":1,"command":"hello"}']
    assert links[0].is_open is False


def test_startup_delay_is_passed_to_link_prepare() -> None:
    client, links = make_client(startup_delay=2.0)

    client.hello()

    assert links[0].startup_delay == 2.0
    assert links[0].prepare_count == 1


def test_boot_log_lines_before_json_are_ignored() -> None:
    def responder(line: str) -> list[str]:
        response = SoftwareSerialSimulator._default_responder(line)[0]
        return [
            "ets Jul 29 2019 12:21:46",
            "rst:0x1 (POWERON_RESET),boot:0x13 (SPI_FAST_FLASH_BOOT)",
            response,
        ]

    client, _links = make_client(responder)

    response = client.hello()

    assert response["command"] == "hello"
    assert client.ignored_lines == [
        "ets Jul 29 2019 12:21:46",
        "rst:0x1 (POWERON_RESET),boot:0x13 (SPI_FAST_FLASH_BOOT)",
    ]


def test_invalid_json_before_valid_response_is_ignored() -> None:
    def responder(line: str) -> list[str]:
        return ["{not json", SoftwareSerialSimulator._default_responder(line)[0]]

    client, _links = make_client(responder)

    response = client.hello()

    assert response["command"] == "hello"
    assert client.ignored_lines == ["{not json"]


def test_valid_status_response() -> None:
    client, _links = make_client()

    response = client.get_status()

    assert response["command"] == "get_status"
    assert response["state"] == "SAFE"
    assert response["output_enable"] is False
    assert response["uptime_ms"] == 1234
    assert response["faults"] == 0


def test_valid_heartbeat_response() -> None:
    client, _links = make_client()

    response = client.heartbeat()

    assert response["command"] == "heartbeat"
    assert response["state"] == "SAFE"
    assert response["output_enable"] is False
    assert response["uptime_ms"] == 1234


def test_malformed_response_rejected_by_single_response_validator() -> None:
    with pytest.raises(SerialResponseError, match="invalid JSON response"):
        validate_controller_response("{bad", 1, "hello")


def test_timeout_raises_clear_error() -> None:
    client, links = make_client(lambda _line: [], timeout=0.5)

    with pytest.raises(SerialTimeoutError, match="timed out waiting for hello"):
        client.hello()

    assert links[0].is_open is False


def test_sequence_mismatch_rejected() -> None:
    client, links = make_client(
        lambda _line: [
            (
                '{"version":1,"sequence":99,"status":"ack","command":"hello",'
                '"state":"SAFE","output_enable":false}'
            )
        ]
    )

    with pytest.raises(SerialResponseError, match="sequence mismatch"):
        client.hello()

    assert links[0].is_open is False


def test_non_safe_state_rejected() -> None:
    client, _links = make_client(
        lambda _line: [
            (
                '{"version":1,"sequence":1,"status":"ack","command":"hello",'
                '"state":"RUNNING","output_enable":false}'
            )
        ]
    )

    with pytest.raises(SerialResponseError, match="not SAFE"):
        client.hello()


def test_output_enable_true_rejected() -> None:
    client, _links = make_client(
        lambda _line: [
            (
                '{"version":1,"sequence":1,"status":"ack","command":"hello",'
                '"state":"SAFE","output_enable":true}'
            )
        ]
    )

    with pytest.raises(SerialResponseError, match="output_enable true"):
        client.hello()
