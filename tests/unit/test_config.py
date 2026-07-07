from pathlib import Path

from neurosync.control.config import load_config


def test_load_config_defaults_when_no_env_file(tmp_path: Path) -> None:
    cfg = load_config(env_file=tmp_path / "missing.env")
    assert cfg.pi_host == "neurosync-pi"
    assert cfg.esp32_target == "esp32"
    assert cfg.esp32_port == "auto"


def test_load_config_reads_env_file(tmp_path: Path) -> None:
    env_file = tmp_path / "hardware.env"
    env_file.write_text(
        "NEUROSYNC_PI_HOST=custom-pi\n# a comment\n\nNEUROSYNC_ESP32_PORT=/dev/ttyUSB0\n"
    )
    cfg = load_config(env_file=env_file)
    assert cfg.pi_host == "custom-pi"
    assert cfg.esp32_port == "/dev/ttyUSB0"
    assert cfg.esp32_target == "esp32"


def test_process_env_overrides_file(tmp_path: Path, monkeypatch) -> None:
    env_file = tmp_path / "hardware.env"
    env_file.write_text("NEUROSYNC_PI_HOST=from-file\n")
    monkeypatch.setenv("NEUROSYNC_PI_HOST", "from-process-env")

    cfg = load_config(env_file=env_file)
    assert cfg.pi_host == "from-process-env"
