from neurosync.control.hardware_discovery import (
    detect_pi_identity,
    list_audio_devices,
    list_serial_ports,
)


def test_list_serial_ports_returns_list() -> None:
    ports = list_serial_ports()
    assert isinstance(ports, list)


def test_detect_pi_identity_reports_architecture() -> None:
    identity = detect_pi_identity()
    assert identity.architecture
    assert identity.python_version
    assert isinstance(identity.is_raspberry_pi, bool)


def test_list_audio_devices_returns_list() -> None:
    devices = list_audio_devices()
    assert isinstance(devices, list)
