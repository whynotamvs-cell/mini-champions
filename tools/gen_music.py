#!/usr/bin/env python3
"""Composes and renders the calm background music loop (own work: no samples, no third-party audio).

    python3 tools/gen_music.py

Writes assets/audio/music.wav: 16-bit mono 32 kHz, a seamless loop of 16 bars at 72 BPM (~53 s).
A soft pad, a round bass, a gentle kalimba-like arpeggio and a sparse pentatonic melody over
Cmaj7 - Am7 - Fmaj7 - G6 / Cmaj7 - Em7 - Fmaj7 - G6sus (the second half adds the melody). A small
reverb gives it room; the reverb tail is folded back onto the start so the loop has no seam.
Deterministic (fixed seeds): running it again writes an identical file.
"""

import math
import os
import random
import struct
import wave

RATE = 32000
BPM = 72
BEAT = 60.0 / BPM
BAR = 4 * BEAT
BARS = 16
LENGTH = BARS * BAR
TAIL = 5.0  # reverb tail rendered past the end and folded onto the start

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "music.wav")


def freq(name):
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    sharp = 1 if len(name) > 2 and name[1] == "#" else 0
    octave = int(name[-1])
    semitone = names[name[0]] + sharp + (octave + 1) * 12
    return 440.0 * 2 ** ((semitone - 69) / 12)


# one bar per chord: (name, pad voicing, bass note)
CHORDS = [
    ("Cmaj7", ("C4", "E4", "G4", "B4"), "C2"),
    ("Am7", ("A3", "C4", "E4", "G4"), "A2"),
    ("Fmaj7", ("F3", "A3", "C4", "E4"), "F2"),
    ("G6", ("G3", "B3", "D4", "E4"), "G2"),
    ("Cmaj7", ("C4", "E4", "G4", "B4"), "C2"),
    ("Em7", ("E3", "G3", "B3", "D4"), "E2"),
    ("Fmaj7", ("F3", "A3", "C4", "E4"), "F2"),
    ("G6sus", ("G3", "C4", "D4", "E4"), "G2"),
]
PENTATONIC = ["C5", "D5", "E5", "G5", "A5", "C6", "A4", "G4"]


class Buf:
    def __init__(self, seconds):
        self.d = [0.0] * int(seconds * RATE)

    def add(self, start, samples, gain=1.0):
        i0 = int(start * RATE)
        n = len(self.d)
        for i, v in enumerate(samples):
            k = i0 + i
            if k >= n:
                break
            self.d[k] += v * gain


def env_pad(t, dur, attack=0.9, release=1.2):
    if t < attack:
        return t / attack
    if t > dur - release:
        return max(0.0, (dur - t) / release)
    return 1.0


def pad_note(f, dur):
    """A warm sustained tone: two slightly detuned sines plus a quiet octave, slow attack and release."""
    n = int(dur * RATE)
    out = []
    w1 = 2 * math.pi * f / RATE
    w2 = 2 * math.pi * (f * 1.0035) / RATE
    w3 = 2 * math.pi * (f * 2.0) / RATE
    for i in range(n):
        t = i / RATE
        s = math.sin(w1 * i) + math.sin(w2 * i) + 0.22 * math.sin(w3 * i)
        out.append(s * 0.33 * env_pad(t, dur))
    return out


def bass_note(f, dur):
    """A round bass: sine plus a quiet second harmonic so small phone speakers still carry it."""
    n = int(dur * RATE)
    out = []
    w = 2 * math.pi * f / RATE
    for i in range(n):
        t = i / RATE
        e = min(1.0, t / 0.03) * (0.55 + 0.45 * math.exp(-t / 0.5)) * min(1.0, max(0.0, (dur - t) / 0.4))
        s = math.sin(w * i) + 0.45 * math.sin(2 * w * i)
        out.append(s * 0.6 * e)
    return out


def kalimba(f, dur=1.6, amp=1.0):
    """A soft plucked tine: a sine with a quick-fading bright overtone and a long gentle decay."""
    n = int(dur * RATE)
    out = []
    w = 2 * math.pi * f / RATE
    for i in range(n):
        t = i / RATE
        s = math.sin(w * i) * math.exp(-t / 0.55)
        s += 0.28 * math.sin(w * 4.0 * i) * math.exp(-t / 0.05)
        s += 0.08 * math.sin(w * 6.3 * i) * math.exp(-t / 0.02)
        out.append(s * amp * min(1.0, t / 0.004) * min(1.0, max(0.0, (dur - t) / 0.2)))
    return out


def flute(f, dur, amp=1.0):
    """A breathy, soft lead: a sine with a gentle vibrato that fades in, slow attack and release."""
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        vib = 1.0 + 0.004 * math.sin(2 * math.pi * 5.0 * t) * min(1.0, t / 0.5)
        phase = 2 * math.pi * f * vib * t
        s = math.sin(phase) + 0.12 * math.sin(2 * phase) + 0.04 * math.sin(3 * phase)
        e = min(1.0, t / 0.12) * min(1.0, max(0.0, (dur - t) / 0.35))
        out.append(s * amp * e * 0.8)
    return out


def reverb(data):
    """A small Schroeder reverb (4 combs, 2 allpass) mixed in quietly for room."""
    combs = [int(RATE * d) for d in (0.0297, 0.0371, 0.0411, 0.0437)]
    out = [0.0] * len(data)
    for delay in combs:
        buf = [0.0] * delay
        idx = 0
        fb = 0.78
        for i, x in enumerate(data):
            y = buf[idx]
            buf[idx] = x + y * fb
            idx += 1
            if idx == delay:
                idx = 0
            out[i] += y
    for delay, g in ((int(RATE * 0.005), 0.7), (int(RATE * 0.0017), 0.7)):
        buf = [0.0] * delay
        idx = 0
        for i, x in enumerate(out):
            y = buf[idx]
            v = x + y * g
            buf[idx] = v
            out[i] = y - v * g
            idx += 1
            if idx == delay:
                idx = 0
    return [d * 0.9 + o * 0.075 for d, o in zip(data, out)]


def lowpass(data, cutoff=4200.0):
    """Take the edge off: a gentle one-pole low-pass."""
    a = 1.0 - math.exp(-2 * math.pi * cutoff / RATE)
    y = 0.0
    out = []
    for x in data:
        y += a * (x - y)
        out.append(y)
    return out


def compose():
    rng = random.Random(72)
    buf = Buf(LENGTH + TAIL)
    for bar in range(BARS):
        name, pad, bass = CHORDS[bar % len(CHORDS)]
        t0 = bar * BAR
        # pad: every voice held a little over the bar so chords flow into each other
        for n in pad:
            buf.add(t0, pad_note(freq(n), BAR + 1.0), 0.17)
        buf.add(t0, bass_note(freq(bass), BAR), 0.62)
        if bar % 2 == 1:
            buf.add(t0 + 2 * BEAT, bass_note(freq(bass) * 1.5, 1.5 * BEAT), 0.28)  # a fifth on beat 3
        # arpeggio: eighth notes through the chord, some steps rest
        tones = [freq(n) * 2 for n in pad]  # an octave above the pad
        pattern = (0, 1, 2, 3, 2, 1, 2, 3)
        for step, idx in enumerate(pattern):
            if step in (0, 4) or rng.random() < 0.62:
                buf.add(t0 + step * BEAT / 2, kalimba(tones[idx], 1.6, 0.5), 0.26)
        # melody: sparse and pentatonic, from bar 5 on
        if bar >= 4:
            for beat in (0.0, 1.5, 2.5):
                if rng.random() < (0.55 if bar < 8 else 0.72):
                    note = rng.choice(PENTATONIC)
                    dur = rng.choice((1.5, 2.0, 2.5)) * BEAT
                    buf.add(t0 + beat * BEAT, flute(freq(note), dur, 0.55), 0.20)
    data = reverb(buf.d)
    data = lowpass(data)
    # fold the reverb tail onto the start so the loop is seamless
    n = int(LENGTH * RATE)
    tail = data[n:]
    body = data[:n]
    for i, v in enumerate(tail):
        if i < n:
            body[i] += v
    return body


def write(path, data, peak=0.5):
    top = max(abs(v) for v in data) or 1.0
    gain = peak / top
    frames = bytearray()
    for v in data:
        frames += struct.pack("<h", int(max(-1.0, min(1.0, v * gain)) * 32767))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(bytes(frames))
    return gain


def main():
    data = compose()
    gain = write(OUT, data)
    n = len(data)
    rms = math.sqrt(sum((v * gain) ** 2 for v in data) / n)
    seam = max(abs(data[0]), abs(data[-1])) * gain
    first = math.sqrt(sum((v * gain) ** 2 for v in data[: RATE // 2]) / (RATE // 2))
    last = math.sqrt(sum((v * gain) ** 2 for v in data[-RATE // 2 :]) / (RATE // 2))
    print(f"music.wav: {n / RATE:.1f} s, {BARS} bars at {BPM} BPM, peak 0.50, rms {rms:.3f}, gain {gain:.2f}")
    print(f"seam: first sample {data[0] * gain:+.4f}, last sample {data[-1] * gain:+.4f}, rms first/last half second {first:.3f}/{last:.3f}")
    print(f"size: {os.path.getsize(OUT) / 1e6:.1f} MB")
    del seam


if __name__ == "__main__":
    main()
