"""Generate Mosslight's original, quiet forest audio using only the stdlib.

Run from any directory: python tools/generate_audio.py
No recordings, downloaded samples, or third-party packages are used.
"""

from __future__ import annotations

from array import array
import math
from pathlib import Path
import random
import sys
import wave


SAMPLE_RATE = 22050
TAU = 2.0 * math.pi
OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "audio"


def smoothstep(value: float) -> float:
    value = min(1.0, max(0.0, value))
    return value * value * (3.0 - 2.0 * value)


def envelope(t: float, duration: float, attack: float = 0.015) -> float:
    if t < 0.0 or t >= duration:
        return 0.0
    return (
        smoothstep(t / attack)
        * math.exp(-4.0 * t / duration)
        * smoothstep((duration - t) / min(0.10, duration / 3.0))
    )


def bell(t: float, frequency: float, duration: float, attack: float = 0.015) -> float:
    return envelope(t, duration, attack) * (
        math.sin(TAU * frequency * t)
        + 0.12 * math.sin(TAU * frequency * 2.0 * t)
    )


def periodic_wind(frames: int, seed: int) -> list[float]:
    """Filter one periodic noise cycle, carrying its settled state over the seam."""
    rng = random.Random(seed)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(frames)]
    slow = 0.0
    soft = 0.0
    # The warm-up has the same data and duration as the exported loop. After
    # this pass, the second pass begins in the periodic steady state.
    for sample in noise:
        slow += 0.024 * (sample - slow)
        soft += 0.085 * (sample - soft)
    result = []
    for sample in noise:
        slow += 0.024 * (sample - slow)
        soft += 0.085 * (sample - soft)
        result.append(slow * 0.52 + soft * 0.16)
    average = sum(result) / frames
    return [sample - average for sample in result]


def save_wave(name: str, channels: list[list[float]]) -> None:
    frames = len(channels[0])
    assert all(len(channel) == frames for channel in channels)
    pcm = array("h")
    peak = 0.0
    for index in range(frames):
        for channel in channels:
            sample = channel[index]
            peak = max(peak, abs(sample))
            # Headroom is intentional. The Godot players attenuate further.
            assert abs(sample) < 0.75, f"Unexpected level in {name}"
            pcm.append(round(sample * 32767.0))
    if sys.byteorder != "little":
        pcm.byteswap()
    path = OUTPUT / name
    with wave.open(str(path), "wb") as output:
        output.setnchannels(len(channels))
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())
    print(f"{name}: {frames / SAMPLE_RATE:.2f}s, {len(channels)} channel(s), peak {peak:.3f}")


def generate_ambience() -> None:
    duration = 14.0
    frames = round(duration * SAMPLE_RATE)
    wind_left = periodic_wind(frames, 601)
    wind_right = periodic_wind(frames, 947)
    left = []
    right = []
    # An integer number of cycles per loop keeps each harmonic continuous.
    notes = [(round(f * duration) / duration, gain) for f, gain in (
        (130.81, 0.018), (196.0, 0.010), (261.63, 0.006),
    )]
    for index in range(frames):
        t = index / SAMPLE_RATE
        phase = TAU * t / duration
        breeze = 0.72 + 0.18 * math.cos(phase) + 0.10 * math.sin(phase * 2.0)
        warmth = sum(gain * math.sin(TAU * frequency * t) for frequency, gain in notes)
        warmth *= 0.75 + 0.25 * math.cos(phase)
        insect_left = 0.0
        insect_right = 0.0
        # Brief, distant tonal calls, with no persistent high-frequency hiss.
        for start, frequency, pan in [(2.7, 1700.0, -0.5), (7.0, 1530.0, 0.6), (11.5, 1820.0, -0.2)]:
            for pulse in range(3):
                local_time = t - start - pulse * 0.11
                if 0.0 <= local_time < 0.075:
                    call = 0.009 * math.sin(math.pi * local_time / 0.075) ** 2
                    call *= math.sin(TAU * frequency * local_time)
                    insect_left += call * (0.75 - pan * 0.25)
                    insect_right += call * (0.75 + pan * 0.25)
        left.append((wind_left[index] * 0.82 + wind_right[index] * 0.18) * breeze + warmth + insect_left)
        right.append((wind_right[index] * 0.82 + wind_left[index] * 0.18) * breeze + warmth + insect_right)
    save_wave("forest_ambience.wav", [left, right])


def generate_cues() -> None:
    rng = random.Random(211)
    definitions = {
        "plant": 0.25,
        "harvest": 0.66,
        "restore": 1.12,
        "toggle": 0.16,
        "clear": 0.38,
        "error": 0.24,
    }
    for name, duration in definitions.items():
        samples = []
        noise = 0.0
        for index in range(round(duration * SAMPLE_RATE)):
            t = index / SAMPLE_RATE
            noise += 0.08 * (rng.uniform(-1.0, 1.0) - noise)
            if name == "plant":
                phase = TAU * (230.0 * t - 150.0 * t * t)
                value = 0.28 * envelope(t, duration, 0.009) * math.sin(phase)
                value += 0.030 * envelope(t, 0.12) * noise
                value += 0.065 * bell(t - 0.035, 523.25, 0.18)
            elif name == "harvest":
                value = 0.19 * bell(t, 659.25, 0.50)
                value += 0.15 * bell(t - 0.11, 783.99, 0.50)
                value += 0.09 * bell(t - 0.22, 1046.50, 0.42)
            elif name == "restore":
                value = 0.0
                for start, frequency, gain in [(0.0, 261.63, 0.17), (0.10, 329.63, 0.14), (0.20, 392.0, 0.12), (0.32, 523.25, 0.11)]:
                    value += gain * bell(t - start, frequency, duration - start, 0.035)
            elif name == "toggle":
                value = 0.20 * bell(t, 392.0, duration, 0.008)
                value += 0.055 * bell(t, 587.33, duration, 0.008)
            elif name == "clear":
                value = 0.18 * bell(t, 174.61, duration, 0.030)
                value += 0.20 * envelope(t, duration, 0.045) * noise
            else:
                phase = TAU * (290.0 * t - 90.0 * t * t)
                value = 0.18 * envelope(t, duration, 0.020) * math.sin(phase)
            samples.append(value)
        save_wave(f"{name}.wav", [samples])


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    generate_ambience()
    generate_cues()


if __name__ == "__main__":
    main()
