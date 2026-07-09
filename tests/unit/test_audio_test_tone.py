from __future__ import annotations

import struct
import wave
from pathlib import Path

from neurosync.audio.test_tone import generate_wav


def read_wav(path: Path) -> tuple[int, list[tuple[int, int]]]:
    with wave.open(str(path), "rb") as wav:
        assert wav.getnchannels() == 2
        assert wav.getsampwidth() == 2
        sample_rate = wav.getframerate()
        raw = wav.readframes(wav.getnframes())

    samples = [
        struct.unpack_from("<hh", raw, offset)
        for offset in range(0, len(raw), 4)
    ]
    return sample_rate, samples


def dominant_frequency(samples: list[int], *, sample_rate: int) -> float:
    crossings = 0
    previous = samples[0]
    for sample in samples[1:]:
        if previous <= 0 < sample or previous >= 0 > sample:
            crossings += 1
        previous = sample
    duration = len(samples) / sample_rate
    return crossings / (2.0 * duration)


def test_left_only_wav_has_expected_rate_duration_and_channel_isolation(tmp_path: Path) -> None:
    out = tmp_path / "left.wav"
    generate_wav(channel="left", freq_hz=1_000.0, seconds=1.0, out_path=out)

    sample_rate, samples = read_wav(out)

    assert sample_rate == 48_000
    assert len(samples) == 48_000
    assert any(left != 0 for left, _right in samples)
    assert all(right == 0 for _left, right in samples)


def test_right_only_wav_has_expected_channel_isolation(tmp_path: Path) -> None:
    out = tmp_path / "right.wav"
    generate_wav(channel="right", freq_hz=1_000.0, seconds=1.0, out_path=out)

    _sample_rate, samples = read_wav(out)

    assert all(left == 0 for left, _right in samples)
    assert any(right != 0 for _left, right in samples)


def test_frequency_is_within_zero_crossing_tolerance(tmp_path: Path) -> None:
    out = tmp_path / "both.wav"
    generate_wav(channel="both", freq_hz=440.0, seconds=2.0, out_path=out)

    sample_rate, samples = read_wav(out)
    left = [sample[0] for sample in samples]

    assert dominant_frequency(left, sample_rate=sample_rate) == 440.0


def test_identification_sequence_is_left_then_right(tmp_path: Path) -> None:
    out = tmp_path / "identify.wav"
    generate_wav(channel="identify", freq_hz=1_000.0, seconds=3.0, out_path=out)

    _sample_rate, samples = read_wav(out)
    first = samples[:48_000]
    middle = samples[48_000:96_000]
    last = samples[96_000:]

    assert any(left != 0 for left, _right in first)
    assert all(right == 0 for _left, right in first)
    assert all(left == 0 and right == 0 for left, right in middle)
    assert all(left == 0 for left, _right in last)
    assert any(right != 0 for _left, right in last)
