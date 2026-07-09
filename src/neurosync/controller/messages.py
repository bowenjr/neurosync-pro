"""Unix-socket IPC request and response helpers."""

from __future__ import annotations

from typing import Any

IPC_VERSION = 1
ALLOWED_COMMANDS = {
    "get_daemon_status",
    "get_controller_status",
    "get_controller_identity",
    "force_reconnect",
    "ping",
}


class IPCMessageError(ValueError):
    """Raised when a local IPC message is malformed or unsupported."""


def validate_request(message: Any) -> tuple[int, str]:
    if not isinstance(message, dict):
        raise IPCMessageError("request must be a JSON object")
    if message.get("version") != IPC_VERSION:
        raise IPCMessageError("unsupported IPC version")
    request_id = message.get("request_id")
    if not isinstance(request_id, int):
        raise IPCMessageError("request_id must be an integer")
    command = message.get("command")
    if not isinstance(command, str):
        raise IPCMessageError("command must be a string")
    if command not in ALLOWED_COMMANDS:
        raise IPCMessageError("unsupported command")
    return request_id, command


def ack_response(request_id: int, **payload: Any) -> dict[str, Any]:
    return {"version": IPC_VERSION, "request_id": request_id, "status": "ack", **payload}


def nak_response(request_id: int | None, error: str) -> dict[str, Any]:
    return {"version": IPC_VERSION, "request_id": request_id, "status": "nak", "error": error}
