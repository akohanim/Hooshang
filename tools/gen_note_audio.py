#!/usr/bin/env python3
"""Generates the musical-tile FEEDBACK CUES -> assets/notes/wrong.wav, success.wav

  wrong    low detuned thud  (sequence broken, start over)
  success  C-E-G-C arpeggio  (all five in order -> glow granted)

The five TILE notes are no longer generated here — note_1..note_5.wav are real
oud recordings now, produced by tools/import_note_audio.py. This script would
happily overwrite them with the old synthesised tones, so it deliberately does
not touch them; NOTES below is kept only to document what the placeholders were
(a C major pentatonic: C5 D5 E5 G5 A5, chosen because a pentatonic has no
dissonant pair, so a wrong-order run still sounded musical).

Bell-ish timbre: fundamental plus a couple of quiet harmonics under an
exponential decay. Pure stdlib, no numpy.

Run from the repo root:  python3 tools/gen_note_audio.py
"""
import math
import os
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "notes")

RATE = 22050
# fundamental, plus (harmonic multiple, amplitude) pairs
HARMONICS = [(1.0, 1.0), (2.0, 0.32), (3.0, 0.10), (4.01, 0.05)]

# Historical only — see the module docstring. NOT regenerated.
NOTES = [
    ("note_1", 523.25),   # C5
    ("note_2", 587.33),   # D5
    ("note_3", 659.25),   # E5
    ("note_4", 783.99),   # G5
    ("note_5", 880.00),   # A5
]


def tone(freq, dur, decay=6.0, amp=0.42, harmonics=HARMONICS):
    """One decaying tone as a list of float samples in -1..1."""
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-decay * t)
        # 4ms attack so it doesn't click on
        env *= min(1.0, t / 0.004)
        s = 0.0
        for mult, a in harmonics:
            s += a * math.sin(2.0 * math.pi * freq * mult * t)
        out.append(s * env * amp / sum(a for _, a in harmonics))
    return out


def mix(layers):
    """Overlay float sample lists, longest wins."""
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, v in enumerate(l):
            out[i] += v
    return out


def write_wav(name, samples):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for v in samples:
            v = max(-1.0, min(1.0, v))
            frames += struct.pack("<h", int(v * 32767))
        w.writeframes(bytes(frames))
    print("wrote", os.path.relpath(path, ROOT), "(%.2fs)" % (len(samples) / RATE))


def main():
    os.makedirs(OUT, exist_ok=True)

    # Wrong: two low, slightly detuned tones beating against each other — reads
    # as "no" without being a harsh buzzer.
    write_wav("wrong", mix([
        tone(146.83, 0.34, decay=11.0, amp=0.40, harmonics=[(1.0, 1.0), (2.0, 0.5)]),
        tone(138.59, 0.34, decay=11.0, amp=0.40, harmonics=[(1.0, 1.0), (2.0, 0.5)]),
    ]))

    # Success: rising C-E-G-C, each note delayed a beat after the last.
    arp = [523.25, 659.25, 783.99, 1046.50]
    layers = []
    for i, f in enumerate(arp):
        pad = [0.0] * int(RATE * 0.085 * i)
        layers.append(pad + tone(f, 0.85, decay=4.0, amp=0.34))
    write_wav("success", mix(layers))


if __name__ == "__main__":
    main()
