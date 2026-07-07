"""Runtime configuration for NeuroSync Pro.

Resolution order (lowest to highest precedence):
1. Built-in defaults below.
2. `~/.config/neurosync/hardware.env` (local, uncommitted, machine-specific).
3. Process environment variables (`NEUROSYNC_*`).
"""

from __future__ import annotations

import os
from dataclasses import dataclass, fields
from pathlib import Path

from platformdirs import user_config_dir

_ENV_PREFIX = "NEUROSYNC_"

_DEFAULTS: dict[str, str] = {
    "PI_HOST": "neurosync-pi",
    "PI_HOSTNAME": "10.0.0.127",
    "PI_USER": "bowen",
    "PI_PATH": "/home/bowen/apps/neurosync-pro",
    "ESP32_TARGET": "esp32",
    "ESP32_PORT": "auto",
    "ESP_IDF_PATH": "auto",
}


def local_hardware_env_path() -> Path:
    """Path to the uncommitted, machine-local hardware config file."""
    return Path(user_config_dir("neurosync")) / "hardware.env"


def _parse_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for raw_line in path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key.startswith(_ENV_PREFIX):
            key = key[len(_ENV_PREFIX) :]
        values[key] = value
    return values


@dataclass(frozen=True)
class NeuroSyncConfig:
    """Resolved hardware/deployment configuration. Read-only at runtime."""

    pi_host: str
    pi_hostname: str
    pi_user: str
    pi_path: str
    esp32_target: str
    esp32_port: str
    esp_idf_path: str

    @property
    def field_to_env_key(self) -> dict[str, str]:
        return {f.name: f.name.upper() for f in fields(self)}


def load_config(env_file: Path | None = None) -> NeuroSyncConfig:
    """Resolve configuration from defaults, the local env file, then process env."""
    values = dict(_DEFAULTS)
    values.update(_parse_env_file(env_file or local_hardware_env_path()))
    for key in list(values):
        env_key = f"{_ENV_PREFIX}{key}"
        if env_key in os.environ:
            values[key] = os.environ[env_key]

    return NeuroSyncConfig(
        pi_host=values["PI_HOST"],
        pi_hostname=values["PI_HOSTNAME"],
        pi_user=values["PI_USER"],
        pi_path=values["PI_PATH"],
        esp32_target=values["ESP32_TARGET"],
        esp32_port=values["ESP32_PORT"],
        esp_idf_path=values["ESP_IDF_PATH"],
    )
