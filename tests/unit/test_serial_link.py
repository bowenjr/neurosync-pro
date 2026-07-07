from __future__ import annotations

import json
from collections.abc import Callable
from typing import Any

import pytest

from neurosync.control.serial_link import (
    DEFAULT_BAUDRATE,
    ControllerClient,
    SerialResponseError,
    SerialTimeoutError,
    validate_controller_response,
)


class SoftwareSerialSimulator:
    """In-memory serial peer for protocol-v1 client tests."""

    def __init__(
        self,
        _port: str,
        _baudrate: int = DEFAULT_BAUDRATE,
        _timeout: float = 1.0,
        *,
        responder: Callable[[str], str | None] | None = None,
    ) -> None:
        self.is_open = False
        self.writes: list[str] = []
        self._response: str | None = None
        self._responder = responder or self._default_responder

    def open(self) -> None:
        self.is_open = True

    def close(self) -> None:
        self.is_open = False

    def write_line(self, line: str) -> None:
        self.writes.append(line)
        self._response = self._responder(line)

    def read_line(self) -> str | None:
        return self._response

    @staticmethod
    def _default_responder(line: str) -> str:
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
            return json.dumps(
                {
                    "version": 1,
                    "sequence": request["sequence"],
                    "status": "nak",
                    "error": "unknown_command",
                },
                separators=(",", ":"),
            )
        return json.dumps(response, separators=(",", ":"))


def make_client(
    responder: Callable[[str], str | None] | None = None,
) -> tuple[ControllerClient, list[SoftwareSerialSimulator]]:
    links: list[SoftwareSerialSimulator] = []

    def link_factory(port: str, baudrate: int, timeout: float) -> SoftwareSerialSimulator:
        link = SoftwareSerialSimulator(port, baudrate, timeout, responder=responder)
        links.append(link)
        return link

    return ControllerClient("/dev/null", link_factory=link_factory), links


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


def test_malformed_response_rejected() -> None:
    with pytest.raises(SerialResponseError, match="invalid JSON response"):
        validate_controller_response("{bad", 1, "hello")


def test_timeout_raises_clear_error() -> None:
    client, _links = make_client(lambda _line: None)

    with pytest.raises(SerialTimeoutError, match="timed out waiting for hello"):
        client.hello()


def test_sequence_mismatch_rejected() -> None:
    client, _links = make_client(
        lambda _line: (
            '{"version":1,"sequence":99,"status":"ack","command":"hello",'
            '"state":"SAFE","output_enable":false}'
        )
    )

    with pytest.raises(SerialResponseError, match="sequence mismatch"):
        client.hello()


def test_non_safe_state_rejected() -> None:
    client, _links = make_client(
        lambda _line: (
            '{"version":1,"sequence":1,"status":"ack","command":"hello",'
            '"state":"RUNNING","output_enable":false}'
        )
    )

    with pytest.raises(SerialResponseError, match="not SAFE"):
        client.hello()


def test_output_enable_true_rejected() -> None:
    client, _links = make_client(
        lambda _line: (
            '{"version":1,"sequence":1,"status":"ack","command":"hello",'
            '"state":"SAFE","output_enable":true}'
        )
    )

    with pytest.raises(SerialResponseError, match="output_enable true"):
        client.hello()
