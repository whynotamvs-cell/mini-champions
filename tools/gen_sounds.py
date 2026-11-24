#!/usr/bin/env python3
"""Synthesizes the sound sprites of the two tracks (no samples, no third-party audio).

    python3 tools/gen_sounds.py

Writes assets/audio/desk.wav and assets/audio/keys.wav: 16-bit mono 44.1 kHz, one file per track
holding every cue back to back ("sprite"). The game plays a cue by starting the sound at the cue's
offset and stopping it after its length (src/shared/Config/Sounds.luau holds the same table;
keep SLOTS and that table in sync).

  Desk Dash     warm marimba / wood tones: soft, rounded, quick decay
  Keyboard Dash bright triangle beeps and clean key clicks

Everything is built from sine and triangle waves with a soft attack and an exponential decay, so
there is no harshness, clipping or DC offset; peaks are kept near -4 dBFS. Deterministic (fixed
seed): running it again writes identical files.
"""

import math
import os
import random
import struct
import wave

RATE = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")

# cue -> (start seconds, length seconds) inside each sprite. Keep in sync with Config/Sounds.luau.
SLOTS = {
    "tick": (0.0, 0.30),
    "go": (0.5, 0.55),
    "jump": (1.2, 0.25),
    "land": (1.7, 0.25),
    "checkpoint": (2.2, 0.60),
    "fall": (3.0, 0.50),
    "finishBronze": (3.8, 1.00),
    "finishSilver": (5.0, 1.30),
    "finishGold": (6.5, 1.90),
    "rejected": (8.6, 0.60),
}
TOTAL = 9.4


def note(name):
    """Frequency of a note like 'C5' or 'F#4'."""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    letter = name[0]
    sharp = 1 if len(name) > 2 and name[1] == "#" else 0
    octave = int(name[-1])
    semitone = names[letter] + sharp + (octave + 1) * 12
    return 440.0 * 2 ** ((semitone - 69) / 12)


class Buffer:
    def __init__(self, seconds):
        self.data = [0.0] * int(seconds * RATE)

    def add(self, start, samples, gain=1.0):
        i0 = int(start * RATE)
        for i, v in enumerate(samples):
            k = i0 + i
            if 0 <= k < len(self.data):
                self.data[k] += v * gain


def fade(samples, attack=0.004, release=0.012):
    n = len(samples)
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    for i in range(min(a, n)):
        samples[i] *= i / a
    for i in range(min(r, n)):
        samples[n - 1 - i] *= i / r
    return samples


def marimba(freq, dur, amp=1.0):
    """A struck wooden bar: fundamental plus a quickly dying overtone at 4x and a click at 10x."""
    n = int(dur * RATE)
    tau1 = 0.30 if freq < 700 else 0.20
    out = []
    for i in range(n):
        t = i / RATE
        s = math.sin(2 * math.pi * freq * t) * math.exp(-t / tau1)
        s += 0.32 * math.sin(2 * math.pi * freq * 4.0 * t) * math.exp(-t / 0.045)
        s += 0.10 * math.sin(2 * math.pi * freq * 9.8 * t) * math.exp(-t / 0.012)
        out.append(s * amp)
    return fade(out, 0.002, 0.03)


def triangle(freq, dur, amp=1.0, tau=0.12):
    """A soft electronic beep: triangle wave (odd harmonics 1/n^2) with an exponential decay."""
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        s = 0.0
        for h, sign in ((1, 1.0), (3, -1.0), (5, 1.0), (7, -1.0)):
            s += sign * math.sin(2 * math.pi * freq * h * t) / (h * h)
        out.append(s * 0.8 * amp * math.exp(-t / tau))
    return fade(out, 0.003, 0.02)


def glide(f0, f1, dur, amp=1.0, tau=0.08, wave_fn=None):
    """A sine sweep from f0 to f1 (exponential in pitch) with a soft envelope."""
    n = int(dur * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        k = i / max(1, n - 1)
        f = f0 * (f1 / f0) ** k
        phase += 2 * math.pi * f / RATE
        s = math.sin(phase)
        env = math.exp(-t / tau) * min(1.0, t / 0.006)
        out.append(s * amp * env)
    return fade(out, 0.002, 0.02)


def thud(freq0, freq1, dur, amp=1.0, tau=0.045):
    """A soft low thump: a fast downward sine sweep with a faint noise tick on top."""
    rng = random.Random(11)
    n = int(dur * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq1 + (freq0 - freq1) * math.exp(-t / 0.03)
        phase += 2 * math.pi * f / RATE
        s = math.sin(phase) * math.exp(-t / tau)
        s += 0.12 * (rng.random() * 2 - 1) * math.exp(-t / 0.004)
        out.append(s * amp)
    return fade(out, 0.002, 0.02)


def click(centre, dur, amp=1.0, seed=3):
    """A clean key click: a very short noise burst through a ringing resonance plus a tiny tone."""
    rng = random.Random(seed)
    n = int(dur * RATE)
    out = []
    y1 = y2 = 0.0
    w = 2 * math.pi * centre / RATE
    r = 0.93
    for i in range(n):
        t = i / RATE
        x = (rng.random() * 2 - 1) * math.exp(-t / 0.0025)
        y = 2 * r * math.cos(w) * y1 - r * r * y2 + x * 0.18
        y2, y1 = y1, y
        s = y + 0.35 * math.sin(2 * math.pi * centre * 0.5 * t) * math.exp(-t / 0.012)
        out.append(s * amp)
    return fade(out, 0.0008, 0.01)


def echo(buf, start, end, taps=((0.032, 0.22), (0.061, 0.14), (0.097, 0.08))):
    """A tiny reverb-like tail: a few quiet delayed copies of the region start..end."""
    i0, i1 = int(start * RATE), int(end * RATE)
    seg = buf.data[i0:i1]
    for delay, gain in taps:
        buf.add(start + delay, seg, gain)


def build_desk():
    b = Buffer(TOTAL)
    s = SLOTS

    def at(cue):
        return s[cue][0]

    b.add(at("tick"), marimba(note("C5"), 0.28, 0.8))
    b.add(at("go"), marimba(note("G5"), 0.30, 0.8))
    b.add(at("go") + 0.09, marimba(note("C6"), 0.42, 0.9))
    b.add(at("jump"), glide(note("D4"), note("A4"), 0.14, 0.5, tau=0.06))
    b.add(at("land"), thud(190, 78, 0.2, 0.9))
    b.add(at("checkpoint"), marimba(note("E5"), 0.30, 0.8))
    b.add(at("checkpoint") + 0.10, marimba(note("G5"), 0.45, 0.85))
    b.add(at("fall"), glide(note("G4"), note("C4"), 0.42, 0.55, tau=0.22))
    # finish jingles: three tiers of the same C major arpeggio
    for cue, notes, gap in (
        ("finishBronze", ("C5", "G5"), 0.14),
        ("finishSilver", ("C5", "E5", "G5"), 0.12),
        ("finishGold", ("C5", "E5", "G5", "C6"), 0.11),
    ):
        t0 = at(cue)
        for k, name in enumerate(notes):
            last = k == len(notes) - 1
            b.add(t0 + k * gap, marimba(note(name), 0.9 if last else 0.4, 0.8 + 0.05 * k))
        if cue == "finishGold":
            b.add(t0 + 4 * gap, marimba(note("E6"), 0.8, 0.45))
            b.add(t0 + 4 * gap, marimba(note("G5"), 0.9, 0.4))
        echo(b, t0, t0 + SLOTS[cue][1] - 0.2)
    b.add(at("rejected"), marimba(note("A3"), 0.30, 0.7))
    b.add(at("rejected") + 0.16, marimba(note("E3"), 0.40, 0.7))
    return b


def build_keys():
    b = Buffer(TOTAL)
    s = SLOTS

    def at(cue):
        return s[cue][0]

    b.add(at("tick"), click(2600, 0.06, 0.9, seed=5))
    b.add(at("tick") + 0.004, triangle(note("A5"), 0.12, 0.5, tau=0.045))
    b.add(at("go"), triangle(note("A5"), 0.16, 0.7, tau=0.07))
    b.add(at("go") + 0.09, triangle(note("E6"), 0.34, 0.8, tau=0.12))
    b.add(at("jump"), click(2100, 0.08, 0.8, seed=7))
    b.add(at("land"), click(1000, 0.1, 0.75, seed=9))
    b.add(at("land") + 0.003, thud(140, 90, 0.1, 0.35, tau=0.03))
    b.add(at("checkpoint"), triangle(note("C6"), 0.14, 0.7, tau=0.06))
    b.add(at("checkpoint") + 0.09, triangle(note("G6"), 0.40, 0.75, tau=0.14))
    b.add(at("fall"), glide(note("A5"), note("A3"), 0.4, 0.5, tau=0.2))
    for cue, notes, gap in (
        ("finishBronze", ("C6", "G6"), 0.10),
        ("finishSilver", ("C6", "E6", "G6"), 0.09),
        ("finishGold", ("C6", "E6", "G6", "C7"), 0.085),
    ):
        t0 = at(cue)
        for k, name in enumerate(notes):
            last = k == len(notes) - 1
            b.add(t0 + k * gap, triangle(note(name), 0.8 if last else 0.22, 0.7 + 0.04 * k, tau=0.25 if last else 0.08))
        if cue == "finishGold":
            for k in range(3):
                b.add(t0 + 5 * gap + k * 0.07, triangle(note("C7") * (1.0 + 0.25 * k), 0.4, 0.22, tau=0.1))
        echo(b, t0, t0 + SLOTS[cue][1] - 0.2)
    b.add(at("rejected"), triangle(note("A3"), 0.2, 0.55, tau=0.09))
    b.add(at("rejected") + 0.2, triangle(note("A3"), 0.3, 0.55, tau=0.12))
    return b


def write_wav(path, buf, target_peak=0.62):
    peak = max(abs(v) for v in buf.data) or 1.0
    gain = target_peak / peak
    frames = bytearray()
    for v in buf.data:
        x = max(-1.0, min(1.0, v * gain))
        frames += struct.pack("<h", int(x * 32767))
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(bytes(frames))
    return gain


def report(name, buf, gain):
    print(f"{name}: {len(buf.data) / RATE:.1f} s, gain applied {gain:.2f}")
    for cue, (start, length) in SLOTS.items():
        seg = buf.data[int(start * RATE) : int((start + length) * RATE)]
        peak = max(abs(v) for v in seg) * gain
        rms = math.sqrt(sum((v * gain) ** 2 for v in seg) / len(seg))
        edge = abs(seg[-1] * gain)
        print(f"  {cue:13s} start {start:4.1f}s len {length:4.2f}s peak {peak:.2f} rms {rms:.3f} last-sample {edge:.4f}")


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, build in (("desk", build_desk), ("keys", build_keys)):
        buf = build()
        gain = write_wav(os.path.join(OUT, f"{name}.wav"), buf)
        report(name, buf, gain)


if __name__ == "__main__":
    main()
