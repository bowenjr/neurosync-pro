"""Process entry point for the persistent controller daemon."""

from __future__ import annotations

import signal
import time

from neurosync.controller.ipc import serve_ipc
from neurosync.controller.service import DEFAULT_SERIAL_PORT, DEFAULT_SOCKET_PATH, ControllerDaemon


def run_daemon(
    *, serial_port: str = DEFAULT_SERIAL_PORT, socket_path: str = DEFAULT_SOCKET_PATH
) -> None:
    daemon = ControllerDaemon(serial_port=serial_port, socket_path=socket_path)
    server = serve_ipc(daemon, socket_path)
    stopping = False

    def request_stop(_signum: int, _frame: object) -> None:
        nonlocal stopping
        stopping = True
        daemon.stop()

    signal.signal(signal.SIGTERM, request_stop)
    signal.signal(signal.SIGINT, request_stop)

    daemon.start()
    try:
        while not stopping:
            server.handle_request()
    finally:
        daemon.stop()
        server.server_close()
        time.sleep(0)
