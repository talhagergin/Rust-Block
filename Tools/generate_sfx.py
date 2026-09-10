#!/usr/bin/env python3
"""Deterministically synthesize the Rust Block sound pack as stereo WAV files."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 44_100
OUTPUT = Path(__file__).resolve().parents[1] / "Rust Block" / "Sounds"


def tone(length: float) -> list[float]:
    return [0.0] * int(length * RATE)


def add_mode(samples: list[float], start: float, frequency: float, amplitude: float, decay: float, pan_phase: float = 0.0) -> None:
    begin = int(start * RATE)
    for index in range(begin, len(samples)):
        t = (index - begin) / RATE
        samples[index] += amplitude * math.sin(math.tau * frequency * t + pan_phase) * math.exp(-t / decay)


def add_chirp(samples: list[float], start: float, duration: float, f0: float, f1: float, amplitude: float, decay: float = 1.0) -> None:
    begin = int(start * RATE)
    end = min(len(samples), begin + int(duration * RATE))
    for index in range(begin, end):
        t = (index - begin) / RATE
        p = t / duration
        frequency_phase = math.tau * (f0 * t + (f1 - f0) * t * t / (2 * duration))
        envelope = math.sin(math.pi * p) ** 0.65 * math.exp(-p / decay)
        samples[index] += amplitude * math.sin(frequency_phase) * envelope


def add_impact(samples: list[float], start: float, amplitude: float, duration: float, seed: int, roughness: float = 0.7) -> None:
    rng = random.Random(seed)
    begin = int(start * RATE)
    end = min(len(samples), begin + int(duration * RATE))
    low = 0.0
    previous = 0.0
    for index in range(begin, end):
        t = (index - begin) / RATE
        white = rng.uniform(-1.0, 1.0)
        low += 0.10 * (white - low)
        high = white - previous
        previous = white
        grit = low * (1 - roughness) + high * roughness
        samples[index] += amplitude * grit * math.exp(-t / max(0.001, duration * 0.22))


def add_rattle(samples: list[float], start: float, duration: float, amplitude: float, seed: int) -> None:
    rng = random.Random(seed)
    time = start
    hit = 0
    while time < start + duration:
        add_impact(samples, time, amplitude * rng.uniform(0.35, 1.0), rng.uniform(0.018, 0.055), seed + hit, 0.82)
        time += rng.uniform(0.018, 0.062)
        hit += 1


def soft_limit(samples: list[float]) -> list[float]:
    peak = max(0.001, max(abs(value) for value in samples))
    gain = min(1.0, 0.94 / peak)
    return [math.tanh(value * gain * 1.35) / math.tanh(1.35) for value in samples]


def stereo(left: list[float], right: list[float] | None = None) -> tuple[list[float], list[float]]:
    if right is None:
        right = left.copy()
        delay = 11
        right = [0.0] * delay + right[:-delay]
    return soft_limit(left), soft_limit(right)


def write(name: str, channels: tuple[list[float], list[float]]) -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    left, right = channels
    if name.startswith("sfx_"):
        # Shared small-room signature: restrained stereo reflections, softer
        # brittle highs, click-free attack and tail. Keep impacts transient-led.
        mastered = []
        for channel_index, channel in enumerate((left, right)):
            opposite = right if channel_index == 0 else left
            result = [0.0] * len(channel)
            low = 0.0
            for i, sample in enumerate(channel):
                low += 0.45 * (sample - low)
                value = sample * 0.65 + low * 0.35
                for delay, gain in [(0.037, 0.10), (0.079, 0.065), (0.127, 0.035)]:
                    offset = int(delay * RATE)
                    if i >= offset:
                        value += opposite[i - offset] * gain
                attack = min(1.0, i / (0.002 * RATE))
                tail = min(1.0, (len(channel) - 1 - i) / (0.035 * RATE))
                result[i] = value * attack * tail * 0.88
            mastered.append(result)
        left, right = mastered
    with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as target:
        target.setnchannels(2)
        target.setsampwidth(2)
        target.setframerate(RATE)
        frames = bytearray()
        for l, r in zip(left, right):
            frames.extend(struct.pack("<hh", int(max(-1, min(1, l)) * 32767), int(max(-1, min(1, r)) * 32767)))
        target.writeframes(frames)


def place() -> tuple[list[float], list[float]]:
    left, right = tone(0.32), tone(0.32)
    add_impact(left, 0.0, 0.75, 0.07, 11, 0.72); add_impact(right, 0.004, 0.72, 0.07, 12, 0.72)
    for frequency, amplitude, decay in [(176, 0.38, 0.11), (427, 0.27, 0.08), (911, 0.15, 0.055), (1540, 0.08, 0.04)]:
        add_mode(left, 0.006, frequency, amplitude, decay)
        add_mode(right, 0.009, frequency * 1.012, amplitude, decay, 0.3)
    return stereo(left, right)


def invalid() -> tuple[list[float], list[float]]:
    left, right = tone(0.48), tone(0.48)
    for start, amp in [(0.0, 0.7), (0.105, 0.42)]:
        add_impact(left, start, amp, 0.09, 31 + int(start * 1000), 0.5)
        add_impact(right, start + 0.006, amp, 0.09, 41 + int(start * 1000), 0.5)
        for frequency in (82, 119, 238):
            add_mode(left, start, frequency, amp * 0.34, 0.16)
            add_mode(right, start, frequency * 0.985, amp * 0.32, 0.16, 0.2)
    return stereo(left, right)


def clear() -> tuple[list[float], list[float]]:
    left, right = tone(1.05), tone(1.05)
    add_chirp(left, 0.0, 0.52, 260, 1220, 0.34, 1.4); add_chirp(right, 0.012, 0.52, 270, 1260, 0.34, 1.4)
    for start, frequency in [(0.18, 523.25), (0.31, 659.25), (0.44, 783.99), (0.57, 1046.5)]:
        add_mode(left, start, frequency, 0.32, 0.23)
        add_mode(right, start + 0.007, frequency * 2.005, 0.11, 0.18)
        add_impact(left, start, 0.18, 0.035, int(frequency), 0.9)
    add_rattle(right, 0.52, 0.3, 0.09, 200)
    return stereo(left, right)


def rust() -> tuple[list[float], list[float]]:
    left, right = tone(1.18), tone(1.18)
    add_rattle(left, 0.0, 0.72, 0.38, 700); add_rattle(right, 0.012, 0.74, 0.36, 900)
    add_chirp(left, 0.02, 0.66, 310, 55, 0.26, 0.8); add_chirp(right, 0.025, 0.68, 292, 52, 0.25, 0.8)
    for start, frequency, amp in [(0.0, 71, 0.34), (0.18, 143, 0.22), (0.46, 93, 0.3), (0.72, 188, 0.16)]:
        add_mode(left, start, frequency, amp, 0.28)
        add_mode(right, start + 0.009, frequency * 1.03, amp, 0.27, 0.45)
    add_impact(left, 0.76, 0.72, 0.16, 1400, 0.64); add_impact(right, 0.77, 0.72, 0.16, 1500, 0.64)
    return stereo(left, right)


def game_over() -> tuple[list[float], list[float]]:
    left, right = tone(1.65), tone(1.65)
    add_chirp(left, 0.0, 1.25, 330, 46, 0.44, 1.6); add_chirp(right, 0.02, 1.25, 326, 44, 0.42, 1.6)
    for start, frequency, amp in [(0.06, 220, 0.3), (0.33, 164.8, 0.32), (0.61, 110, 0.38), (0.94, 55, 0.42)]:
        add_mode(left, start, frequency, amp, 0.42); add_mode(right, start, frequency * 1.01, amp, 0.44, 0.35)
    add_impact(left, 0.92, 0.74, 0.22, 1701, 0.55); add_impact(right, 0.935, 0.74, 0.22, 1702, 0.55)
    return stereo(left, right)


def start() -> tuple[list[float], list[float]]:
    left, right = tone(0.95), tone(0.95)
    add_chirp(left, 0.02, 0.5, 95, 520, 0.3, 1.2); add_chirp(right, 0.03, 0.5, 102, 540, 0.3, 1.2)
    for begin, frequency in [(0.28, 392), (0.40, 523.25), (0.53, 783.99)]:
        add_mode(left, begin, frequency, 0.29, 0.25); add_mode(right, begin + 0.008, frequency * 2, 0.1, 0.18)
    add_impact(left, 0.0, 0.32, 0.08, 181); add_impact(right, 0.004, 0.32, 0.08, 182)
    return stereo(left, right)


def ui_tap() -> tuple[list[float], list[float]]:
    left, right = tone(0.2), tone(0.2)
    add_impact(left, 0.0, 0.42, 0.04, 51, 0.78); add_impact(right, 0.003, 0.4, 0.04, 52, 0.78)
    add_mode(left, 0.0, 640, 0.25, 0.055); add_mode(right, 0.003, 690, 0.22, 0.055)
    return stereo(left, right)


def power_up() -> tuple[list[float], list[float]]:
    left, right = tone(0.88), tone(0.88)
    add_chirp(left, 0.0, 0.48, 180, 980, 0.34, 1.4); add_chirp(right, 0.012, 0.48, 190, 1040, 0.34, 1.4)
    for begin, frequency in [(0.22, 523.25), (0.34, 659.25), (0.46, 880), (0.58, 1174.66)]:
        add_mode(left, begin, frequency, 0.25, 0.18); add_mode(right, begin + 0.006, frequency * 1.5, 0.12, 0.14)
    add_impact(left, 0.0, 0.24, 0.06, 2101, 0.85); add_impact(right, 0.004, 0.24, 0.06, 2102, 0.85)
    return stereo(left, right)


def coin() -> tuple[list[float], list[float]]:
    left, right = tone(0.46), tone(0.46)
    for start_time, frequency in [(0.0, 1318.5), (0.095, 1760.0), (0.19, 2093.0)]:
        add_mode(left, start_time, frequency, 0.28, 0.11)
        add_mode(right, start_time + 0.004, frequency * 1.012, 0.26, 0.11, 0.2)
        add_impact(left, start_time, 0.12, 0.025, 2200 + int(start_time * 1000), 0.92)
    return stereo(left, right)


def blast() -> tuple[list[float], list[float]]:
    left, right = tone(1.08), tone(1.08)
    add_impact(left, 0.0, 1.0, 0.24, 5101, 0.58); add_impact(right, 0.012, 1.0, 0.24, 5102, 0.58)
    add_chirp(left, 0.0, 0.42, 210, 38, 0.48, 0.72); add_chirp(right, 0.008, 0.44, 198, 35, 0.47, 0.72)
    for start_time, frequency, amplitude in [(0.0, 52, 0.48), (0.03, 104, 0.34), (0.12, 286, 0.2), (0.31, 137, 0.18)]:
        add_mode(left, start_time, frequency, amplitude, 0.36)
        add_mode(right, start_time + 0.009, frequency * 1.025, amplitude, 0.35, 0.4)
    add_rattle(left, 0.18, 0.62, 0.18, 5300); add_rattle(right, 0.2, 0.6, 0.17, 5500)
    return stereo(left, right)


def music() -> tuple[list[float], list[float]]:
    # Eight bars at 96 BPM. Fold every note/reverb tail around the loop boundary;
    # unlike a fade-out/fade-in, this preserves the groove at every repetition.
    beat = 60 / 96
    duration = 32 * beat
    left, right = tone(duration), tone(duration)
    chords = [(57, 60, 64, 67), (53, 57, 60, 64), (48, 55, 59, 62), (55, 59, 62, 65)]
    def note(start: float, midi: int, level: float, decay: float, pan: float, pad: bool = False) -> None:
        frequency = 440 * 2 ** ((midi - 69) / 12)
        length = int(decay * 9 * RATE)
        begin = int(start * RATE)
        for sample in range(length):
            t = sample / RATE
            attack = 1 - math.exp(-t / (0.12 if pad else 0.004))
            signal = math.sin(math.tau * frequency * t) + (0.08 if pad else 0.22) * math.sin(math.tau * frequency * 2 * t)
            value = signal * level * attack * math.exp(-t / decay)
            position = (begin + sample) % len(left)
            left[position] += value * (1 - pan * 0.4)
            right[position] += value * (1 + pan * 0.4)
            # Quiet ping-pong reflections, also circular.
            right[(position + int(beat * 0.75 * RATE)) % len(right)] += value * 0.16
            left[(position + int(beat * 1.5 * RATE)) % len(left)] += value * 0.09
    for bar in range(8):
        chord = chords[bar % 4]
        start = bar * 4 * beat
        for index, midi in enumerate(chord):
            note(start, midi + 12, 0.024, 0.95, (index - 1.5) / 2, pad=True)
        for pulse in range(4):
            when = start + pulse * beat
            note(when, chord[0] - 12, 0.14 if pulse % 2 == 0 else 0.08, 0.22, 0)
            if pulse != 3 or bar % 2 == 0:
                note(when + beat * 0.5, chord[(pulse + bar) % 4] + 24, 0.075, 0.18, (-1) ** pulse * 0.6)
            # Soft clockwork percussion, with tiny attack ramps to avoid clicks.
            tick = tone(0.13)
            add_impact(tick, 0, 0.055, 0.09, 6000 + bar * 4 + pulse, 0.7)
            for i, value in enumerate(tick):
                value *= min(1, i / 100)
                position = (int((when + beat * 0.5) * RATE) + i) % len(left)
                left[position] += value * 0.7; right[position] += value
    return stereo(left, right)


if __name__ == "__main__":
    sounds = {
        "sfx_place": place(), "sfx_invalid": invalid(), "sfx_clear": clear(),
        "sfx_rust": rust(), "sfx_game_over": game_over(), "sfx_start": start(), "sfx_ui_tap": ui_tap(),
        "sfx_power_up": power_up(), "sfx_coin": coin(), "sfx_blast": blast(), "music_workshop": music(),
    }
    for filename, data in sounds.items():
        write(filename, data)
        print(OUTPUT / f"{filename}.wav")
