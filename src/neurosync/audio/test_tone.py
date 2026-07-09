"""Dependency-free WAV test-tone generation for PiFi DAC bench checks."""

from __future__ import annotations

import argparse
import math
import struct
import wave
from collections.abc import Iterable
from pathlib import Path

DEFAULT_SAMPLE_RATE = 48_000
DEFAULT_AMPLITUDE = 0.25
PCM_MAX = 32767

StereoSample = tuple[int, int]


def sine_sample(index: int, *, freq_hz: float, sample_rate: int, amplitude: float) -> int:
    """Return one signed 16-bit PCM sine sample."""
    value = math.sin(2.0 * math.pi * freq_hz * (index / sample_rate))
    return int(round(value * amplitude * PCM_MAX))


def _validate_params(*, freq_hz: float, seconds: float, sample_rate: int, amplitude: float) -> None:
    if freq_hz <= 0:
        raise ValueError("frequency must be positive")
    if seconds <= 0:
        raise ValueError("seconds must be positive")
    if sample_rate <= 0:
        raise ValueError("sample rate must be positive")
    if not 0.0 < amplitude <= 1.0:
        raise ValueError("amplitude must be > 0.0 and <= 1.0")


def tone_samples(
    *,
    channel: str,
    freq_hz: float,
    seconds: float,
    sample_rate: int = DEFAULT_SAMPLE_RATE,
    amplitude: float = DEFAULT_AMPLITUDE,
) -> list[StereoSample]:
    """Generate stereo samples for a single test tone."""
    if channel not in {"left", "right", "both"}:
        raise ValueError("channel must be left, right, or both")
    _validate_params(freq_hz=freq_hz, seconds=seconds, sample_rate=sample_rate, amplitude=amplitude)

    frame_count = round(seconds * sample_rate)
    samples: list[StereoSample] = []
    for index in range(frame_count):
        sample = sine_sample(index, freq_hz=freq_hz, sample_rate=sample_rate, amplitude=amplitude)
        if channel == "left":
            samples.append((sample, 0))
        elif channel == "right":
            samples.append((0, sample))
        else:
            samples.append((sample, sample))
    return samples


def identification_samples(
    *,
    freq_hz: float,
    seconds: float,
    sample_rate: int = DEFAULT_SAMPLE_RATE,
    amplitude: float = DEFAULT_AMPLITUDE,
) -> list[StereoSample]:
    """Generate a tone-coded L-then-R channel identification sequence."""
    _validate_params(freq_hz=freq_hz, seconds=seconds, sample_rate=sample_rate, amplitude=amplitude)

    frame_count = round(seconds * sample_rate)
    left_end = frame_count // 3
    right_start = (frame_count * 2) // 3
    samples: list[StereoSample] = []
    for index in range(frame_count):
        if index < left_end:
            sample = sine_sample(
                index,
                freq_hz=freq_hz,
                sample_rate=sample_rate,
                amplitude=amplitude,
            )
            samples.append((sample, 0))
        elif index >= right_start:
            sample = sine_sample(
                index - right_start,
                freq_hz=freq_hz,
                sample_rate=sample_rate,
                amplitude=amplitude,
            )
            samples.append((0, sample))
        else:
            samples.append((0, 0))
    return samples


def write_wav(path: Path, samples: Iterable[StereoSample], *, sample_rate: int) -> None:
    """Write stereo 16-bit PCM WAV data."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        for left, right in samples:
            wav.writeframes(struct.pack("<hh", left, right))


def generate_wav(
    *,
    channel: str,
    freq_hz: float,
    seconds: float,
    out_path: Path,
    sample_rate: int = DEFAULT_SAMPLE_RATE,
    amplitude: float = DEFAULT_AMPLITUDE,
) -> None:
    """Generate one WAV file for the requested test pattern."""
    if channel == "identify":
        samples = identification_samples(
            freq_hz=freq_hz,
            seconds=seconds,
            sample_rate=sample_rate,
            amplitude=amplitude,
        )
    else:
        samples = tone_samples(
            channel=channel,
            freq_hz=freq_hz,
            seconds=seconds,
            sample_rate=sample_rate,
            amplitude=amplitude,
        )
    write_wav(out_path, samples, sample_rate=sample_rate)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate stereo WAV test tones.")
    parser.add_argument(
        "--channel",
        choices=("left", "right", "both", "identify"),
        required=True,
        help="left, right, both, or identify for tone-coded L then R",
    )
    parser.add_argument("--freq", type=float, default=1_000.0, help="tone frequency in Hz")
    parser.add_argument("--seconds", type=float, default=5.0, help="duration in seconds")
    parser.add_argument("--out", type=Path, required=True, help="output WAV path")
    parser.add_argument("--sample-rate", type=int, default=DEFAULT_SAMPLE_RATE)
    parser.add_argument(
        "--amplitude",
        type=float,
        default=DEFAULT_AMPLITUDE,
        help="linear amplitude, 0.0 to 1.0; default is conservative for line-level checks",
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()
    generate_wav(
        channel=args.channel,
        freq_hz=args.freq,
        seconds=args.seconds,
        out_path=args.out,
        sample_rate=args.sample_rate,
        amplitude=args.amplitude,
    )


if __name__ == "__main__":
    main()
