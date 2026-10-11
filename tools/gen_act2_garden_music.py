#!/usr/bin/env python3
"""Act 2 score: cut "Sunlit Garden Path" into bar-aligned cues.

The source is ONE continuous 60s piece in four 15s sections — A Garden
Introduction, Exploring Neighborhood Ponds, Playful Wonder, Loop Coda — at a
measured 100.0 BPM in 4/4 (beat 0.600s, bar 2.4s, first beat at 0.025s). 15s is
25 beats, six bars and a beat, so a section cannot be looped at its own 15s
length without the bar lurching, and measured, every section's END matches the
NEXT section's start (spectral similarity ~0.8) far better than its own (~0.35).
So each looping cue is cut on that section's own downbeat to a whole number of
bars, and its seam is a one-beat equal-power crossfade into the music that
actually preceded its start — never a hard splice.

  garden_intro.ogg   0.000 .. ponds loop start   one-shot; runs straight into
                                                 the ponds loop (contiguous
                                                 audio, so no seam at all)
  garden_ponds.ogg   5 bars from 16.825s         loops (Neighborhood Ponds)
  garden_wonder.ogg  6 bars from 30.025s         loops (Playful Wonder)
  garden_coda.ogg    45.025 .. end               one-shot; its own fade-out
  garden_rest.ogg    one bar of silence          loops; "no music" as a clip,
                                                 so stopping and starting are
                                                 bar-quantized crossfades too

Section downbeats were measured per section (low-band onset strength on each
beat-in-bar), because the generator restarted the bar at sections 2 and 3:
Ponds' downbeat is global beat 28, Wonder's beat 50, the Coda's beat 75.

Wired up by `scripts/act2_music.gd` (an AudioStreamInteractive). Needs ffmpeg
and numpy. Re-run after replacing the source:
  python3 tools/gen_act2_garden_music.py
"""
import subprocess
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'assets/music/source/sunlit_garden_path.mp3'
OUT = ROOT / 'assets/music'
SR = 44100
BEAT = 0.6           # 100 BPM
PHASE = 0.025        # time of beat 0
XFADE_BEATS = 1      # loop seam


def t(beat):
    return PHASE + beat * BEAT


def decode():
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(SRC), '-ac', '2', '-ar', str(SR),
                                   '-f', 'f32le', '-'])
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def s(sec):
    return int(round(sec * SR))


def loop(x, first_beat, bars):
    """`bars` bars from `first_beat`. The loop's LAST beat crossfades (equal
    power) into the beat that preceded its start, so the end runs into the top
    exactly as the original did — and the first pass starts on untouched audio,
    which is what lets the intro hand straight into the ponds loop."""
    a, b = s(t(first_beat)), s(t(first_beat + 4 * bars))
    n = s(XFADE_BEATS * BEAT)
    body = x[a:b].copy()
    lead = x[a - n:a]
    assert len(lead) == n, 'loop needs one beat of real music before it'
    k = np.linspace(0.0, 1.0, n, dtype=np.float32)[:, None]
    body[-n:] = body[-n:] * np.cos(k * np.pi / 2) + lead * np.sin(k * np.pi / 2)
    return body


def write(name, audio):
    wav = OUT / f'{name}.f32'
    audio.astype(np.float32).tofile(wav)
    subprocess.check_call(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '2',
                           '-i', str(wav), '-c:a', 'libvorbis', '-q:a', '6', str(OUT / f'{name}.ogg')])
    wav.unlink()
    print(f'{name}.ogg  {len(audio) / SR:7.3f}s  ({len(audio) / SR / BEAT:5.2f} beats)')


def main():
    x = decode()
    ponds_beat, wonder_beat, coda_beat = 28, 50, 75
    write('garden_intro', x[:s(t(ponds_beat))])
    write('garden_ponds', loop(x, ponds_beat, 5))
    write('garden_wonder', loop(x, wonder_beat, 6))
    write('garden_coda', x[s(t(coda_beat)):])
    write('garden_rest', np.zeros((s(4 * BEAT), 2), dtype=np.float32))


if __name__ == '__main__':
    main()
