"""Process entry point for the persistent controller daemon."""

from __future__ import annotations

import signal
import threading
from pathlib import Path

from neurosync.controller.ipc import serve_ipc
from neurosync.controller.service import DEFAULT_SERIAL_PORT, DEFAULT_SOCKET_PATH, ControllerDaemon


def _remove_socket_file(socket_path: str) -> None:
    path = Path(socket_path)
    if path.is_socket():
        path.unlink()


def run_daemon(
    *, serial_port: str = DEFAULT_SERIAL_PORT, socket_path: str = DEFAULT_SOCKET_PATH
) -> None:
    shutdown_requested = threading.Event()

    def request_stop(_signum: int, _frame: object) -> None:
        shutdown_requested.set()

    signal.signal(signal.SIGTERM, request_stop)
    signal.signal(signal.SIGINT, request_stop)

    daemon: ControllerDaemon | None = None
    server = None
    try:
        daemon = ControllerDaemon(serial_port=serial_port, socket_path=socket_path)
        server = serve_ipc(daemon, socket_path)
        if shutdown_requested.is_set():
            return
        daemon.start()
        while not shutdown_requested.is_set():
            server.handle_request()
    finally:
        if daemon is not None:
            daemon.stop()
        if server is not None:
            server.server_close()
        _remove_socket_file(socket_path)
