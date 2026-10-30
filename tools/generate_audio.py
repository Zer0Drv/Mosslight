"""Generate Mosslight's original, quiet forest audio using only the stdlib.

Run from any directory: python tools/generate_audio.py
No recordings, downloaded samples, or third-party packages are used.
"""

from __future__ import annotations

from array import array
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import sys
import wave


SAMPLE_RATE = 22050
TAU = 2.0 * math.pi
OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
PACK_OUTPUT = OUTPUT / "v2"
PACK_RECORDS: list[dict] = []


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


def write_asset(name: str, channels: list[list[float]], *, peak: float,
                purpose: str, loop: bool = False, connected: bool = True) -> None:
    """Write a deterministic PCM asset and measure the actual quantized output."""
    frames = len(channels[0])
    assert frames > 0 and all(len(channel) == frames for channel in channels)
    if loop:
        for index, channel in enumerate(channels):
            average = sum(channel) / frames
            channels[index] = [value - average for value in channel]
    else:
        # Remove any low-frequency bias without lifting the silent endpoints.
        taper = [smoothstep(i / (SAMPLE_RATE * 0.01)) * smoothstep((frames - 1 - i) / (SAMPLE_RATE * 0.03)) for i in range(frames)]
        taper_sum = sum(taper)
        for index, channel in enumerate(channels):
            correction = sum(channel) / taper_sum
            channels[index] = [value - correction * taper[i] for i, value in enumerate(channel)]
    maximum = max(abs(value) for channel in channels for value in channel)
    assert maximum > 0.001, f"Silent source: {name}"
    gain = peak / maximum
    pcm_channels = [[round(value * gain * 32767) for value in channel] for channel in channels]
    pcm = array("h", (pcm_channels[channel][frame]
                      for frame in range(frames) for channel in range(len(channels))))
    if sys.byteorder != "little":
        pcm.byteswap()
    path = PACK_OUTPUT / (name + ".wav")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(len(channels))
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())
    sample_count = frames * len(channels)
    rms = math.sqrt(sum(value * value for channel in pcm_channels for value in channel) / sample_count) / 32768
    actual_peak = max(abs(value) for channel in pcm_channels for value in channel) / 32768
    seam = max(abs(channel[0] - channel[-1]) for channel in pcm_channels) / 32768
    max_step = max(abs(b - a) for channel in pcm_channels for a, b in zip(channel, channel[1:])) / 32768
    dc = max(abs(sum(channel) / frames / 32768) for channel in pcm_channels)
    assert 0.0005 < rms < 0.3 and actual_peak < 0.6
    assert dc < 0.002, f"DC offset: {name}"
    if loop:
        assert seam <= max_step + 2 / 32768 and seam < 0.02, f"Loop seam: {name}"
    else:
        assert all(abs(channel[0]) <= 1 and abs(channel[-1]) <= 1 for channel in pcm_channels), name
    PACK_RECORDS.append({
        "file": name + ".wav", "purpose": purpose, "runtime": connected,
        "duration_seconds": frames / SAMPLE_RATE, "sample_rate": SAMPLE_RATE,
        "channels": len(channels), "pcm_bits": 16, "loop": loop,
        "peak_dbfs": round(20 * math.log10(actual_peak), 3),
        "rms_dbfs": round(20 * math.log10(rms), 3), "dc_offset": round(dc, 8),
        "seam_jump": round(seam, 8), "maximum_adjacent_jump": round(max_step, 8),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size,
    })
    print(f"v2/{name}.wav: {frames / SAMPLE_RATE:.2f}s, peak {actual_peak:.3f}, RMS {rms:.4f}")


def filtered_noise(count: int, seed: int, rate: float = 0.15) -> list[float]:
    rng = random.Random(seed)
    state = 0.0
    result = []
    for _ in range(count):
        state += rate * (rng.uniform(-1, 1) - state)
        result.append(state)
    return result


def pluck(t: float, frequency: float, duration: float, softness: float = 0.25) -> float:
    return envelope(t, duration, 0.009) * (
        math.sin(TAU * frequency * t)
        + softness * math.sin(TAU * frequency * 2.01 * t) * math.exp(-9 * max(0, t))
        + 0.05 * math.sin(TAU * frequency * 3.98 * t) * math.exp(-14 * max(0, t))
    )


def generate_pack_ambience() -> None:
    """One shared night bed; seasonal variants await their actual game systems."""
    duration = 24.0
    frames = round(duration * SAMPLE_RATE)
    wind_a = periodic_wind(frames, 310601)
    wind_b = periodic_wind(frames, 310947)
    channels = [[], []]
    for i in range(frames):
        t = i / SAMPLE_RATE
        phase = TAU * t / duration
        breeze = 0.72 + 0.18 * math.cos(phase) + 0.10 * math.sin(phase * 3)
        distant = 0.0
        # Soft three-pulse forest calls; no constant bright insect whine.
        for start, freq in ((3.1, 1460), (10.3, 1320), (18.2, 1580)):
            for pulse in range(3):
                u = t - start - pulse * 0.18
                if 0 <= u < 0.12:
                    distant += 0.009 * math.sin(math.pi * u / 0.12) ** 2 * math.sin(TAU * (freq * u - 120 * u * u))
        # A very quiet stream detail follows an integer-cycle modulation.
        water = 0.013 * math.sin(TAU * 37 * t) * (0.5 + 0.5 * math.sin(phase * 5))
        channels[0].append((0.85 * wind_a[i] + 0.15 * wind_b[i]) * breeze + distant * 0.65 + water)
        channels[1].append((0.85 * wind_b[i] + 0.15 * wind_a[i]) * breeze + distant * 0.85 - water * 0.3)
    write_asset("forest_night", channels, peak=0.22, purpose="当前灯圃夜间微风、远虫与细水声", loop=True)


def generate_pack_cues() -> None:
    definitions = [
        ("plant", 0.42, "播种：柔和土壤落点与木质短音"),
        ("harvest_moon", 0.88, "收获月苔：清亮露滴三音"),
        ("harvest_bell", 0.96, "收获灯铃：温暖铃簇三音"),
        ("nourish", 0.72, "露养成功：水滴落下和向上泛音"),
        ("clear", 0.44, "移除未熟植物：叶片轻擦与软土"),
        ("seed_select", 0.16, "切换种子卡：轻木片确认"),
        ("lamp_on", 0.48, "点灯：灯芯轻燃与上行暖音"),
        ("lamp_off", 0.40, "熄灯：短柔气流与下行音"),
        ("restore", 1.75, "修复苔灯：石座轻敲与四音亮起"),
        ("complete", 3.40, "当前三灯修复完成：完整暖和弦；不是最终黎明曲"),
        ("denied", 0.28, "当前操作无效或材料不足：克制的木质低音"),
        ("overlay", 0.18, "切换光域预览：轻纸片与单音"),
        ("pause", 0.20, "打开暂停菜单：短降音"),
        ("resume", 0.20, "关闭暂停菜单：短升音"),
    ]
    for variant in range(3):
        definitions.append((f"footstep_{variant + 1:02d}", 0.22 + variant * 0.02, "苔地脚步变体：低沉软踏与轻叶擦声"))
    for number, (name, duration, purpose) in enumerate(definitions):
        frames = round(duration * SAMPLE_RATE)
        noise = filtered_noise(frames, 310000 + number * 137)
        samples = []
        for i in range(frames):
            t = i / SAMPLE_RATE
            value = 0.0
            if name == "plant":
                value = 0.32 * envelope(t, 0.24, 0.008) * math.sin(TAU * (160 * t - 80 * t * t))
                value += 0.18 * noise[i] * envelope(t, 0.23) + 0.07 * pluck(t - 0.035, 523.25, 0.35)
            elif name in ("harvest_moon", "harvest_bell"):
                notes = (783.99, 1046.5, 1318.51) if name == "harvest_moon" else (523.25, 659.25, 783.99)
                for n, frequency in enumerate(notes):
                    value += (0.24 - n * 0.04) * pluck(t - n * 0.105, frequency, duration - n * 0.105)
            elif name == "nourish":
                for start, frequency in ((0.0, 680), (0.085, 880), (0.19, 1120)):
                    u = t - start
                    value += 0.18 * envelope(u, 0.25) * math.sin(TAU * (frequency * u + 480 * u * u))
                value += 0.075 * pluck(t - 0.15, 1046.5, 0.55)
            elif name == "clear":
                value = 0.46 * noise[i] * envelope(t, duration, 0.04)
                value += 0.1 * pluck(t, 146.83, 0.30, 0.1)
            elif name == "seed_select":
                value = 0.26 * pluck(t, 440, duration, 0.15)
                value += 0.08 * noise[i] * envelope(t, 0.06, 0.003)
            elif name in ("lamp_on", "lamp_off"):
                frequencies = (392, 523.25) if name == "lamp_on" else (392, 261.63)
                value = 0.13 * pluck(t, frequencies[0], duration)
                value += 0.18 * pluck(t - 0.08, frequencies[1], duration - 0.08)
                value += 0.18 * noise[i] * envelope(t, 0.20, 0.025)
            elif name in ("restore", "complete"):
                notes = (261.63, 329.63, 392, 523.25) if name == "restore" else (261.63, 392, 523.25, 659.25, 783.99, 1046.5)
                for n, frequency in enumerate(notes):
                    start = n * (0.14 if name == "restore" else 0.19)
                    value += (0.17 - n * 0.012) * pluck(t - start, frequency, duration - start, 0.15)
                value += 0.06 * noise[i] * envelope(t, 0.1, 0.004)
            elif name == "denied":
                value = 0.24 * pluck(t, 196, duration, 0.04) + 0.05 * pluck(t - 0.06, 174.61, 0.20, 0.04)
            elif name == "overlay":
                value = 0.16 * pluck(t, 587.33, duration, 0.07) + 0.13 * noise[i] * envelope(t, 0.12)
            elif name in ("pause", "resume"):
                first, second = (440, 329.63) if name == "pause" else (329.63, 440)
                value = 0.16 * pluck(t, first, 0.15, 0.08) + 0.13 * pluck(t - 0.055, second, 0.145, 0.08)
            else:
                variant = int(name[-2:])
                value = 0.27 * envelope(t, duration, 0.008) * math.sin(TAU * ((95 + variant * 8) * t - 45 * t * t))
                value += 0.48 * noise[i] * envelope(t - 0.012, duration - 0.012, 0.012)
            samples.append(value)
        write_asset(name, [samples], peak=0.38 if name.startswith("footstep") else 0.48, purpose=purpose)


def generate_spare_music() -> None:
    """A preview only: never started by ForestAudio during ordinary gardening."""
    duration = 32.0
    frames = round(duration * SAMPLE_RATE)
    channels = [[0.0] * frames, [0.0] * frames]
    chords = ((130.81, 196, 261.63), (174.61, 220, 329.63),
              (110, 164.81, 261.63), (98, 196, 293.66))
    melody = ((0.0, 523.25), (2.5, 659.25), (5, 783.99), (8, 659.25),
              (11, 523.25), (14, 440), (16.5, 523.25), (20, 587.33),
              (23, 392), (26, 523.25), (29, 659.25))
    events = []
    for bar in range(8):
        for degree, frequency in enumerate(chords[bar % 4]):
            events.append((bar * 4 + degree * 0.45, frequency, 4.5, 0.055, (-0.3, 0.15, 0.3)[degree]))
    for number, (start, frequency) in enumerate(melody):
        events.append((start, frequency, 3.0, 0.12, 0.15 * (-1) ** number))
    for start, frequency, length, gain, pan in events:
        for i in range(round(length * SAMPLE_RATE)):
            value = gain * pluck(i / SAMPLE_RATE, frequency, length, 0.10)
            index = (round(start * SAMPLE_RATE) + i) % frames
            channels[0][index] += value * (0.75 - pan * 0.25)
            channels[1][index] += value * (0.75 + pan * 0.25)
            # Circular, quiet stereo echoes make the release cross the loop seam.
            channels[1][(index + round(0.275 * SAMPLE_RATE)) % frames] += value * 0.13
            channels[0][(index + round(0.425 * SAMPLE_RATE)) % frames] += value * 0.08
    write_asset("lamplight_sketch", channels, peak=0.34, purpose="32秒伴灯曲音色草稿；备用、未接入，不代表四季伴灯系统已完成", loop=True, connected=False)


def generate_audition() -> None:
    """A convenient, correctly attenuated sound-effects reel; not a game asset."""
    duration = 20.0
    frames = round(duration * SAMPLE_RATE)
    channels = [[0.0] * frames, [0.0] * frames]
    schedule = [(0.7, "footstep_01"), (1.0, "footstep_02"), (1.3, "footstep_03"),
                (2.1, "seed_select"), (3, "plant"), (4, "nourish"), (5.3, "harvest_moon"),
                (6.7, "harvest_bell"), (8.2, "clear"), (9.2, "lamp_on"), (10.1, "lamp_off"),
                (11.1, "denied"), (12, "overlay"), (12.7, "pause"), (13.1, "resume"),
                (13.7, "restore"), (16.1, "complete")]
    for start, name in schedule:
        with wave.open(str(PACK_OUTPUT / (name + ".wav")), "rb") as source:
            samples = array("h", source.readframes(source.getnframes()))
        if sys.byteorder != "little":
            samples.byteswap()
        for i, sample in enumerate(samples):
            target = round(start * SAMPLE_RATE) + i
            if target < frames:
                gain = 0.48 if name.startswith("footstep") else 0.8
                channels[0][target] += sample / 32768 * gain
                channels[1][target] += sample / 32768 * gain
    write_asset("audition", channels, peak=0.48, purpose="20秒音效顺序试听；未接入游戏", connected=False)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--legacy", action="store_true", help="Reproduce the original seven files instead of the v2 pack.")
    args = parser.parse_args()
    if args.legacy:
        OUTPUT.mkdir(parents=True, exist_ok=True)
        generate_ambience()
        generate_cues()
        return
    PACK_OUTPUT.mkdir(parents=True, exist_ok=True)
    generate_pack_ambience()
    generate_pack_cues()
    generate_spare_music()
    generate_audition()
    manifest = {
        "version": 2, "date": "2026-10-31", "generator": "tools/generate_audio.py",
        "source": "Original deterministic synthesis using Python standard library; no recordings, external samples, or third-party music.",
        "seed_family": 310000, "format": "22050 Hz / 16-bit little-endian PCM WAV",
        "validation": "Every file: non-silent RMS, peak below -4.4 dBFS, DC below 0.002; one-shots start/end at zero; loops seam below 0.02 and no greater than maximum interior sample step.",
        "assets": PACK_RECORDS,
    }
    (PACK_OUTPUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
