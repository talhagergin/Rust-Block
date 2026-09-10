#!/usr/bin/env python3
"""Validate the bundled original audio without external packages."""
import array
import math
import sys
import wave
from pathlib import Path

folder = Path(__file__).resolve().parents[1] / "Rust Block" / "Sounds"
files = sorted(folder.glob("*.wav"))
assert len(files) == 11, "Expected ten effects and one music loop"
for path in files:
    with wave.open(str(path), "rb") as audio:
        assert (audio.getnchannels(), audio.getsampwidth(), audio.getframerate()) == (2, 2, 44100), path.name
        frames = audio.getnframes()
        samples = array.array("h", audio.readframes(frames))
        if sys.byteorder != "little":
            samples.byteswap()
    peak = max(abs(value) for value in samples) / 32768
    rms = math.sqrt(sum((value / 32768) ** 2 for value in samples) / len(samples))
    assert 0.001 < rms < 0.8 and peak < 0.999, f"Invalid level/clipping: {path.name}"
    if path.stem == "music_workshop":
        assert frames == 20 * 44100, "Loop must contain eight complete bars at 96 BPM"
        seam = max(abs(samples[-2] - samples[0]), abs(samples[-1] - samples[1])) / 32768
        assert seam < 0.015, f"Audible loop discontinuity: {seam}"
        print(f"music seam delta: {seam:.6f}")
    print(f"{path.name}: {frames / 44100:.2f}s, peak {peak:.3f}, RMS {rms:.3f}")
