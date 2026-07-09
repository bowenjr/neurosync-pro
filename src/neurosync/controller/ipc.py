"""Newline-delimited JSON Unix-socket IPC for the controller daemon."""

from __future__ import annotations

import json
import os
import socket
import socketserver
from typing import Any

from neurosync.controller.messages import ack_response, nak_response, validate_request
from neurosync.controller.service import DEFAULT_SOCKET_PATH, ControllerDaemon, prepare_socket_path


class ControllerRequestHandler(socketserver.StreamRequestHandler):
    def handle(self) -> None:
        daemon: ControllerDaemon = self.server.daemon  # type: ignore[attr-defined]
        for raw_line in self.rfile:
            request_id: int | None = None
            try:
                message = json.loads(raw_line.decode("utf-8"))
                request_id, command = validate_request(message)
                payload = daemon.handle_command(command)
                response = ack_response(request_id, **payload)
            except Exception as exc:  # noqa: BLE001 - local client gets structured NAK
                response = nak_response(request_id, str(exc))
            self.wfile.write(json.dumps(response, separators=(",", ":")).encode("utf-8") + b"\n")


class ControllerIPCServer(socketserver.ThreadingUnixStreamServer):
    daemon: ControllerDaemon
    daemon_threads = True
    allow_reuse_address = False


def serve_ipc(
    daemon: ControllerDaemon, socket_path: str = DEFAULT_SOCKET_PATH
) -> ControllerIPCServer:
    prepare_socket_path(socket_path)
    server = ControllerIPCServer(socket_path, ControllerRequestHandler)
    server.daemon = daemon
    server.timeout = 0.2
    os.chmod(socket_path, 0o660)
    return server


def request(
    command: str, *, socket_path: str = DEFAULT_SOCKET_PATH, request_id: int = 1
) -> dict[str, Any]:
    payload = {"version": 1, "request_id": request_id, "command": command}
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(2.0)
        client.connect(socket_path)
        client.sendall(json.dumps(payload, separators=(",", ":")).encode("utf-8") + b"\n")
        data = b""
        while not data.endswith(b"\n"):
            chunk = client.recv(4096)
            if not chunk:
                break
            data += chunk
    if not data:
        raise RuntimeError("controller daemon returned no response")
    response = json.loads(data.decode("utf-8"))
    if not isinstance(response, dict):
        raise RuntimeError("controller daemon response was not an object")
    return response
