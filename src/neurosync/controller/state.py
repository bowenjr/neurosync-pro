"""Controller daemon state model."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum
from typing import Any


class DaemonState(StrEnum):
    STARTING = "STARTING"
    DISCONNECTED = "DISCONNECTED"
    CONNECTING = "CONNECTING"
    SAFE = "SAFE"
    DEGRADED = "DEGRADED"
    FAULT = "FAULT"
    STOPPING = "STOPPING"


SAFE_CONTROLLER_STATE = "SAFE"


@dataclass(frozen=True)
class ControllerSnapshot:
    daemon_state: DaemonState = DaemonState.STARTING
    controller_connected: bool = False
    controller_state: str | None = None
    output_enable: bool | None = None
    last_heartbeat_monotonic: float | None = None
    serial_port: str = "/dev/ttyUSB0"
    identity: dict[str, Any] = field(default_factory=dict)
    status: dict[str, Any] = field(default_factory=dict)
    last_error: str | None = None
    reconnect_attempts: int = 0
    next_reconnect_delay_s: float | None = None

    def heartbeat_age_ms(self, now: float) -> int | None:
        if self.last_heartbeat_monotonic is None:
            return None
        return max(0, int((now - self.last_heartbeat_monotonic) * 1000))
