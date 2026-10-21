#!/usr/bin/env python3
"""Act III's score — "The Sea" — synthesised, seven cues, one theme.

Everything is made here (numpy + ffmpeg for the Ogg encode), deterministic, the
same way the voice blips and note tiles are made: no source recording. The
theme is in Dastgah-e Shur on D — the mode the title screen and Act I already
speak — with its real E KORON (a half-flat second, 50 cents under E), and it
travels the act the way the colour does (docs/act3/ACT3_DESIGN.md):

  sea_shore.ogg   loop   Ch I    surf, and the theme in single santur notes with
                                  long silence between: black and white
  sea_deep.ogg    loop   Ch II   a low D drone opens up; santur arpeggios; the
                                  first phrase on a breathy ney
  sea_wreck.ogg   loop   Ch III  his office, drowned: a flickering tube hum, the
                                  theme on a detuned, muffled electric piano
  sea_reef.ogg    loop   Ch IV   glass bells, shimmering pads, the WHOLE melody
  sea_trench.ogg  loop   Ch V    the ink: a heartbeat that will not slow down,
                                  a semitone tremolo, swells from below
  sea_floor.ogg   once   Ch V    one held chord in the light; then the theme
                                  turns to Mahur (major) — let it go
  sea_dawn.ogg    loop   epilogue the full theme, warm, in Mahur

Wired up by scripts/act3/act3_music.gd. See assets/music/README.md.

    python3 tools/gen_act3_sea_music.py
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/music'
SR = 44100
RNG = np.random.default_rng(1979)

# ------------------------------------------------------------------ pitch --
# MIDI numbers, fractional for the koron. Shur on D: D Ek F G A Bb C.
D3, D4, D5 = 50, 62, 74
SHUR = {'D': 62, 'Ek': 63.5, 'F': 65, 'G': 67, 'A': 69, 'Bb': 70, 'C': 72}
MAHUR = {'D': 62, 'E': 64, 'F#': 66, 'G': 67, 'A': 69, 'B': 71, 'C#': 73}


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def note(scale, name, octave=0):
    return scale[name] + 12 * octave


# The theme: (note, octave offset, beats). Phrase A descends to the tonic
# through the koron; phrase B answers from below and rises to C.
PHRASE_A = [('A', 0, 2), ('G', 0, 1), ('F', 0, 1), ('Ek', 0, 2), ('F', 0, 1), ('G', 0, 3),
            ('A', 0, 1), ('Bb', 0, 1), ('A', 0, 1), ('G', 0, 1), ('F', 0, 2), ('Ek', 0, 1), ('D', 0, 4)]
PHRASE_B = [('D', 0, 1), ('F', 0, 1), ('G', 0, 1), ('A', 0, 2), ('C', 1, 1), ('Bb', 0, 1), ('A', 0, 2),
            ('G', 0, 1), ('A', 0, 1), ('F', 0, 1), ('G', 0, 1), ('Ek', 0, 2), ('D', 0, 4)]


def to_mahur(phrase):
    swap = {'Ek': 'E', 'F': 'F#', 'Bb': 'B', 'C': 'C#'}
    return [(swap.get(n, n), o, b) for n, o, b in phrase]


# --------------------------------------------------------------- buffers ---

TAIL = 6.0


def silence(seconds):
    # Every buffer carries TAIL extra seconds so notes ringing past a loop's
    # end can be folded back onto its head (fold) instead of being cut.
    return np.zeros((int((seconds + TAIL) * SR), 2))


def fold(buf, seconds, loop=True):
    """Trim to `seconds`; for a loop, add what rang past the end onto the
    start, so the seam carries every note across it and nothing clicks."""
    n = int(seconds * SR)
    out = buf[:n].copy()
    if loop:
        tail = buf[n:]
        out[:len(tail)] += tail
    else:
        fade = min(len(out), int(2.0 * SR))
        out[-fade:] *= np.linspace(1, 0, fade)[:, None]
    return out


def mix_in(buf, sound, at, gain=1.0, pan=0.0):
    i = int(at * SR)
    if i >= len(buf):
        return
    n = min(len(sound), len(buf) - i)
    if sound.ndim == 1:
        left = np.sqrt(0.5 * (1 - pan))
        right = np.sqrt(0.5 * (1 + pan))
        buf[i:i + n, 0] += sound[:n] * gain * left * 1.414
        buf[i:i + n, 1] += sound[:n] * gain * right * 1.414
    else:
        buf[i:i + n] += sound[:n] * gain


def env_adsr(n, a, d, s, r):
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n)
    e[:na] = np.linspace(0, 1, na, endpoint=False) if na else e[:na]
    nd = min(nd, n - na)
    if nd > 0:
        e[na:na + nd] = np.linspace(1, s, nd, endpoint=False)
    if nr > 0 and nr < n:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


# ------------------------------------------------------------ instruments --

def santur(m, dur=2.6, vel=1.0):
    """Struck strings: inharmonic partials, each course doubled ~1.5 cents
    apart (a santur has four strings a course, and the beating is its shimmer),
    plus the hammer's brief click."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    out = np.zeros(n)
    for detune in (-0.75, 0.75):
        fd = f * 2 ** (detune / 1200)
        for k in range(1, 11):
            fk = fd * k * (1 + 0.0004 * k * k)
            if fk > SR / 2.2:
                break
            amp = (1.0 / k ** 1.25) * (1.4 if k == 2 else 1.0)
            decay = 1.6 + k * 1.15
            out += amp * np.exp(-decay * t) * np.sin(2 * np.pi * fk * t + RNG.random() * 6.28)
    click = RNG.standard_normal(n) * np.exp(-t * 160) * 0.12
    out = (out + click) * vel
    out *= np.minimum(1, t * 400)
    return out * 0.32


def ney(m, dur, vel=1.0, vib=5.2):
    """A breathy end-blown flute: a sine and a soft octave, slow attack,
    vibrato that blooms into the note, and breath noise riding on it."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    depth = 0.006 * np.minimum(1, t / 0.6)
    phase = 2 * np.pi * f * np.cumsum(1 + depth * np.sin(2 * np.pi * vib * t)) / SR
    tone = np.sin(phase) + 0.28 * np.sin(2 * phase) + 0.08 * np.sin(3 * phase)
    breath = lowpass(RNG.standard_normal(n), 2400) * 0.22
    e = env_adsr(n, 0.12, 0.2, 0.85, min(0.35, dur * 0.4))
    return (tone + breath) * e * vel * 0.22


def bell(m, dur=3.0, vel=1.0, ratio=3.5, index=2.4):
    """Glass: FM, the modulation index decaying faster than the tone."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    mod = index * np.exp(-t * 3.0) * np.sin(2 * np.pi * f * ratio * t)
    out = np.sin(2 * np.pi * f * t + mod) * np.exp(-t * 1.4)
    out *= np.minimum(1, t * 600)
    return out * vel * 0.18


def epiano(m, dur=2.4, vel=1.0):
    """The drowned office's piano: a soft FM tine, detuned by a slow wobble
    (tape, or water), muffled."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m) * (1 + 0.004 * np.sin(2 * np.pi * 0.7 * t))
    phase = 2 * np.pi * np.cumsum(f) / SR
    mod = 1.2 * np.exp(-t * 4) * np.sin(phase * 1.0)
    out = np.sin(phase + mod) * np.exp(-t * 0.9)
    return lowpass(out * np.minimum(1, t * 300), 2200) * vel * 0.24


def pad(ms, dur, vel=1.0, bright=6, attack=2.5, release=3.0):
    """A slow string/choir pad: detuned saws, a few harmonics each, a slow
    filter-ish swell by fading the upper harmonics in."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for m in ms:
        f = hz(m)
        for detune in (-6, 0, 6):
            fd = f * 2 ** (detune / 1200)
            for k in range(1, bright + 1):
                fk = fd * k
                if fk > SR / 2.5:
                    break
                swell = np.minimum(1, t / (attack * (0.6 + k * 0.25)))
                out += (1.0 / k) * swell * np.sin(2 * np.pi * fk * t + RNG.random() * 6.28)
    e = env_adsr(n, attack, 0.5, 1.0, release)
    return out * e * vel * 0.03 / max(len(ms), 1)


def drone(m, dur, vel=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    out = np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * 2 * f * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.05 * t))
    return out * env_adsr(n, 4.0, 0.5, 1.0, 4.0) * vel * 0.12


def surf(dur, vel=1.0, period=9.0):
    """The shore: noise, darkened, swelling with each wave and drawing back."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    noise = lowpass(RNG.standard_normal(n), 900) + lowpass(RNG.standard_normal(n), 3500) * 0.25
    wave_env = (0.35 + 0.65 * np.clip(np.sin(2 * np.pi * t / period) ** 3, 0, 1)) * (0.8 + 0.2 * np.sin(2 * np.pi * t / 23.0))
    return noise * wave_env * vel * 0.09


def heartbeat(vel=1.0):
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    f = 52 * np.exp(-t * 6) + 34
    thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    return thump * vel * 0.55


def hum(dur, vel=1.0):
    """A fluorescent tube, under water: 120 Hz and its odd harmonics, stuttering."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = sum((1.0 / k) * np.sin(2 * np.pi * 120 * k * t) for k in (1, 3, 5, 7))
    flicker = 0.75 + 0.25 * np.sign(np.sin(2 * np.pi * 0.31 * t) + np.sin(2 * np.pi * 2.3 * t) * 0.8)
    return lowpass(out * flicker, 1200) * vel * 0.025


def glide(m0, m1, dur, vel=1.0):
    """A distant whale-like call: a slow sine portamento, all fundamentals."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    m = m0 + (m1 - m0) * (0.5 - 0.5 * np.cos(np.pi * t / dur))
    phase = 2 * np.pi * np.cumsum(hz(m)) / SR
    return np.sin(phase) * np.sin(np.pi * t / dur) ** 2 * vel * 0.07


# ---------------------------------------------------------------- effects --

def lowpass(x, cutoff):
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    spec *= 1 / np.sqrt(1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(spec, len(x))


_IR = {}


def reverb(buf, wet=0.35, seconds=3.6, dark=4000):
    """Convolution with a synthetic hall: decorrelated decaying noise per
    channel, darkened, so the sea sounds like a large space under water."""
    key = (seconds, dark)
    if key not in _IR:
        n = int(seconds * SR)
        t = np.arange(n) / SR
        ir = np.stack([lowpass(RNG.standard_normal(n), dark) * np.exp(-t * 6.9 / seconds) for _ in range(2)], 1)
        ir[:int(0.012 * SR)] = 0
        ir /= np.sqrt((ir ** 2).sum(0))
        _IR[key] = ir
    ir = _IR[key]
    out = np.zeros_like(buf)
    size = 1 << int(np.ceil(np.log2(len(buf) + len(ir))))
    for c in range(2):
        conv = np.fft.irfft(np.fft.rfft(buf[:, c], size) * np.fft.rfft(ir[:, c], size), size)
        # Wrap the tail onto the head so a loop's reverb carries across its seam.
        full = conv[:len(buf) + len(ir)]
        wrapped = full[:len(buf)].copy()
        tail = full[len(buf):]
        wrapped[:len(tail)] += tail
        out[:, c] = wrapped
    return buf * (1 - wet) + out * wet * 0.9


def master(buf, peak_db=-1.5):
    buf = buf - buf.mean(0)
    peak = np.abs(buf).max() or 1.0
    return buf / peak * 10 ** (peak_db / 20)


def write_ogg(name, buf, loop):
    data = (np.clip(buf, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / 'x.wav'
        with wave.open(str(wav), 'wb') as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        subprocess.check_call(['ffmpeg', '-v', 'error', '-y', '-i', str(wav), '-c:a', 'libvorbis', '-q:a', '6',
                               str(OUT / name)])
    imp = OUT / (name + '.import')
    if not imp.exists():
        imp.write_text('[remap]\n\nimporter="oggvorbisstr"\ntype="AudioStreamOggVorbis"\n\n[params]\n\n'
                       f'loop={"true" if loop else "false"}\nloop_offset=0\nbpm=0\nbeat_count=0\nbar_beats=4\n')
    print(f'  {name}: {len(buf) / SR:.1f}s {"loop" if loop else "once"}')


# ------------------------------------------------------------------- cues --

def play_phrase(buf, phrase, scale, start, beat, inst, gain=1.0, octave=0, pan=0.0, hold=1.0):
    at = start
    for name, octv, beats in phrase:
        m = note(scale, name, octv + octave)
        mix_in(buf, inst(m, beats * beat * hold + 0.4), at, gain, pan)
        at += beats * beat
    return at


def shore():
    dur = 48.0
    buf = silence(dur)
    mix_in(buf, np.stack([surf(dur, 1.9, 9.0), surf(dur, 1.9, 11.0)], 1), 0)
    # Single notes of the theme, long silence between: the shore is line art.
    beat = 1.05
    at = 2.0
    for i, (name, octv, beats) in enumerate(PHRASE_A):
        if i % 2 == 1:
            continue
        m = note(SHUR, name, octv)
        mix_in(buf, santur(m, 4.0, 0.8), at, 1.0, pan=-0.3 + 0.6 * ((i * 37) % 10) / 10)
        at += beats * beat * 1.9 + 0.6
        if at > dur - 6:
            break
    for at in (11.0, 31.0):
        mix_in(buf, bell(note(SHUR, 'A', 1), 5.0, 0.35, 2.0, 1.2), at, 1.0, 0.4)
    buf = fold(buf, dur, True)
    return master(reverb(buf, 0.45, 4.2, 3000), -3.0)


def deep():
    beat = 60 / 64
    bars = 12
    dur = bars * 4 * beat
    buf = silence(dur)
    mix_in(buf, drone(D3 - 12, dur), 0, 1.0)
    mix_in(buf, pad([D3, D3 + 7, D3 + 15], dur, 0.9, 5, 5.0, 5.0), 0, 1.0)
    arp = ['D', 'F', 'A', 'C', 'A', 'F']
    for b in range(bars * 4 * 2):
        name = arp[b % len(arp)]
        m = note(SHUR, name, 0 if b % 12 < 6 else -1)
        mix_in(buf, santur(m, 2.0, 0.45 + 0.15 * ((b % 4) == 0)), b * beat / 2, 1.0, pan=0.25 * np.sin(b))
    play_phrase(buf, PHRASE_A, SHUR, 4 * 4 * beat, beat, ney, 0.9, 0, -0.1)
    mix_in(buf, glide(D3 - 5, D3 + 2, 5.0), 2.0, 1.0, 0.6)
    mix_in(buf, glide(D3 + 3, D3 - 4, 6.0), 26.0, 1.0, -0.6)
    buf = fold(buf, dur, True)
    return master(reverb(buf, 0.4, 3.8, 3500), -2.5)


def wreck():
    beat = 60 / 58
    bars = 12
    dur = bars * 4 * beat
    buf = silence(dur)
    mix_in(buf, hum(dur), 0, 1.0)
    mix_in(buf, pad([D3, D3 + 3, D3 + 10], dur, 0.8, 4, 4.0, 4.0), 0, 1.0)
    at = 2 * beat
    at = play_phrase(buf, PHRASE_A, SHUR, at, beat, epiano, 0.9, 0, 0.15)
    play_phrase(buf, PHRASE_B[:7], SHUR, at + beat, beat, epiano, 0.7, -1, -0.15)
    # A creak from the building: a slow filtered-noise sweep.
    n = int(2.5 * SR)
    t = np.arange(n) / SR
    creak = lowpass(RNG.standard_normal(n), 700) * np.sin(np.pi * t / 2.5) ** 2 * 0.05
    mix_in(buf, creak, 17.0, 1.0, 0.7)
    buf = fold(buf, dur, True)
    return master(reverb(buf, 0.42, 3.4, 2600), -3.0)


def reef():
    beat = 60 / 78
    bars = 16
    dur = bars * 4 * beat
    buf = silence(dur)
    chords = [[D3, D3 + 3, D3 + 7, D3 + 10], [D3 - 4, D3, D3 + 3], [D3 - 2, D3 + 1.5, D3 + 5], [D3, D3 + 3, D3 + 7]]
    for c in range(4):
        mix_in(buf, pad([m + 12 for m in chords[c]], 4 * 4 * beat + 2, 0.9, 6, 2.0, 2.5), c * 16 * beat, 1.0)
    # Glass bells: a rising, glittering arpeggio, one per half-beat.
    seq = ['D', 'F', 'A', 'C', 'D', 'C', 'A', 'F']
    for b in range(bars * 8):
        if b % 8 == 7:
            continue
        m = note(SHUR, seq[b % 8], 1)
        mix_in(buf, bell(m, 2.0, 0.38 + 0.1 * (b % 4 == 0)), b * beat / 2, 1.0, pan=0.5 * np.sin(b * 0.7))
    at = play_phrase(buf, PHRASE_A, SHUR, 2 * beat, beat, ney, 1.0, 0, 0.0)
    play_phrase(buf, PHRASE_B, SHUR, at + 2 * beat, beat, ney, 1.0, 0, 0.0)
    play_phrase(buf, PHRASE_B, SHUR, at + 2 * beat, beat, lambda m, d: santur(m, 2.2, 0.5), 0.8, -1, 0.3)
    buf = fold(buf, dur, True)
    return master(reverb(buf, 0.36, 3.2, 6000), -2.0)


def trench():
    beat = 60 / 104
    bars = 12
    dur = bars * 4 * beat
    buf = silence(dur)
    mix_in(buf, drone(D3 - 12, dur, 1.3), 0, 1.0)
    mix_in(buf, pad([D3, D3 + 1, D3 + 6], dur, 0.7, 7, 3.0, 2.0), 0, 1.0)
    # The heartbeat: lub-dub on every beat, getting heavier.
    for b in range(bars * 4):
        g = 0.6 + 0.4 * b / (bars * 4)
        mix_in(buf, heartbeat(g), b * beat, 1.0)
        mix_in(buf, heartbeat(g * 0.6), b * beat + 0.18, 1.0)
    # A semitone tremolo on the santur: D and E-flat, the koron pulled tight.
    for k in range(bars * 16):
        m = note(SHUR, 'D', -1) if k % 2 == 0 else note(SHUR, 'D', -1) + 1
        mix_in(buf, santur(m, 0.5, 0.28), k * beat / 4, 1.0, pan=0.35 if k % 2 else -0.35)
    # Swells from below.
    for at in (0.0, dur / 2):
        n = int(dur / 2 * SR)
        t = np.arange(n) / SR
        swell = lowpass(RNG.standard_normal(n), 300) * (t / (dur / 2)) ** 2 * 0.25
        mix_in(buf, swell, at, 1.0)
    buf = fold(buf, dur, True)
    return master(reverb(buf, 0.3, 2.6, 2400), -1.5)


def floor():
    beat = 60 / 60
    dur = 70.0
    buf = silence(dur)
    # One held chord in the light: D and A, and the third withheld...
    mix_in(buf, pad([D3, D3 + 7, D3 + 12, D3 + 19], 34.0, 1.0, 5, 8.0, 8.0), 0, 1.0)
    for at in (6.0, 15.0, 24.0):
        mix_in(buf, bell(note(SHUR, 'A', 1), 6.0, 0.25, 2.0, 1.0), at, 1.0, 0.3)
    # ...then the F-sharp arrives, and it is Mahur: the theme, in major.
    mix_in(buf, pad([D3, D3 + 4, D3 + 7, D3 + 16], 38.0, 1.0, 5, 6.0, 8.0), 30.0, 1.0)
    play_phrase(buf, to_mahur(PHRASE_A), MAHUR, 34.0, beat * 1.1, lambda m, d: santur(m, 3.0, 0.7), 1.0, 0, 0.0)
    play_phrase(buf, to_mahur(PHRASE_A), MAHUR, 34.0, beat * 1.1, ney, 0.55, 1, 0.0, hold=0.95)
    buf = fold(buf, dur, False)
    return master(reverb(buf, 0.5, 5.0, 5000), -2.5)


def dawn():
    beat = 60 / 72
    bars = 16
    dur = bars * 4 * beat
    buf = silence(dur)
    prog = [[D3, D3 + 4, D3 + 7], [D3 + 7 - 12, D3 + 11 - 12, D3 + 14 - 12], [D3 + 5, D3 + 9, D3 + 12],
            [D3 + 7 - 12, D3 + 11 - 12, D3 + 14 - 12]]
    for c in range(4):
        mix_in(buf, pad([m + 12 for m in prog[c]], 16 * beat + 2, 0.9, 6, 2.5, 3.0), c * 16 * beat, 1.0)
        mix_in(buf, drone(prog[c][0] - 12, 16 * beat + 2, 0.7), c * 16 * beat, 1.0)
    arp = [0, 1, 2, 1]
    for b in range(bars * 8):
        chord = prog[(b // 32) % 4]
        m = chord[arp[b % 4]] + 12
        mix_in(buf, santur(m, 1.8, 0.35), b * beat / 2, 1.0, pan=0.3 * np.sin(b * 0.5))
    at = play_phrase(buf, to_mahur(PHRASE_A), MAHUR, 4 * beat, beat, ney, 1.0, 0, 0.0)
    play_phrase(buf, to_mahur(PHRASE_B), MAHUR, at + 4 * beat, beat, ney, 1.0, 0, 0.0)
    buf = fold(buf, dur, True)
    return master(reverb(buf, 0.4, 3.6, 6500), -2.0)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn, loop in (('sea_shore.ogg', shore, True), ('sea_deep.ogg', deep, True),
                           ('sea_wreck.ogg', wreck, True), ('sea_reef.ogg', reef, True),
                           ('sea_trench.ogg', trench, True), ('sea_floor.ogg', floor, False),
                           ('sea_dawn.ogg', dawn, True)):
        write_ogg(name, fn(), loop)


if __name__ == '__main__':
    main()
