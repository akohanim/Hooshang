#!/usr/bin/env python3
"""Turn a generated ElevenLabs track into a seamless, level-matched game loop.

Generated music does not loop on its own. For each track this:
  1. measures the beat grid (tempo, phase, which beat of the bar is the
     downbeat) from onset strength,
  2. tries every bar-aligned loop of at least MIN_LOOP seconds and keeps the
     one whose END best matches its START — compared over the two bars that
     follow each point, on a log-spectral fingerprint, so the seam lands where
     the music is genuinely doing the same thing,
  3. crossfades the loop's last bar (equal power) into the bar that preceded
     its start, exactly as `gen_act2_garden_music.py` does, and
  4. levels it to TARGET_RMS so every act's score sits at the same loudness
     under the Music player's own volume_db.

Writes assets/music/<name>.ogg and prints the loop it chose; the result is
also recorded in assets/audio/elevenlabs_v2/manifest.json by the caller.

  python3 tools/master_elevenlabs_music.py prison_theme darkshang_theme
"""
import json, subprocess, sys
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'assets/audio/elevenlabs_v2/source'
OUT = ROOT / 'assets/music'
SR = 44100
MIN_LOOP = 60.0      # seconds; long enough not to feel like a repeat
TAIL_GUARD = 4.0     # never loop through the generated ending
TARGET_RMS = -17.0   # dBFS, matched to the garden score's sections
# Tracks authored as a loop already: (start, end) in seconds, used as-is with
# no search and no crossfade. "Escape From Homayun" (darkshang_theme) is four
# 30 s sections at 120 BPM — 15 bars each — written to chain, and its end
# runs back into its first downbeat (0.03 s) cleanly (seam jump 0.048 against
# a 0.26 sample step). The automatic search would cut across the sections.
FIXED_LOOPS = {'darkshang_theme': (0.03, 120.03)}


def decode(path, sr, mono):
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path), '-ac', '1' if mono else '2',
                                   '-ar', str(sr), '-f', 'f32le', '-'])
    a = np.frombuffer(raw, dtype=np.float32)
    return a if mono else a.reshape(-1, 2).copy()


def beat_grid(x, sr):
    hop = 64
    n = len(x) // hop
    e = np.log(np.sqrt((x[:n * hop].reshape(n, hop) ** 2).mean(1)) + 1e-5)
    on = np.concatenate([[0], np.maximum(np.diff(e), 0)])
    fps = sr / hop
    dur = len(x) / sr
    best = None
    for bpm in np.arange(60, 180.01, 0.05):
        p = 60 / bpm
        for ph in np.arange(0, p, 0.01):
            sc = on[(np.arange(ph, dur - 1, p) * fps).astype(int)].mean()
            if best is None or sc > best[0]:
                best = (sc, bpm, ph)
    _, bpm, ph = best
    p = 60 / bpm
    beats = np.arange(ph, dur, p)
    strength = [on[(beats[k::4] * fps).astype(int)].mean() for k in range(4)]
    return bpm, ph, int(np.argmax(strength))


def fingerprint(x, sr, start, seconds):
    a = x[int(start * sr):int((start + seconds) * sr)].astype(np.float64)
    frames = a[:len(a) // 2048 * 2048].reshape(-1, 2048) * np.hanning(2048)
    spec = np.log(np.abs(np.fft.rfft(frames, axis=1))[:, 4:400] + 1e-4)
    spec -= spec.mean()
    return spec.ravel() / (np.linalg.norm(spec) + 1e-9)


def choose_loop(x, sr, bpm, ph, downbeat):
    beat = 60 / bpm
    bar = 4 * beat
    dur = len(x) / sr
    first = ph + downbeat * beat
    starts = np.arange(first, dur, bar)
    best = None
    for a in starts[1:6]:                      # skip the very first bar
        for b in starts:
            if b - a < MIN_LOOP or b + 2 * bar > dur - TAIL_GUARD:
                continue
            with np.errstate(all="ignore"):  # spurious Accelerate matmul warnings on macOS
                score = float(fingerprint(x, sr, a, 2 * bar) @ fingerprint(x, sr, b, 2 * bar))
            if best is None or score > best[0]:
                best = (score, a, b)
    return best, bar


def master(name):
    src = SRC / f'{name}.mp3'
    mono = decode(src, 22050, True)
    bpm, ph, downbeat = beat_grid(mono, 22050)
    x = decode(src, SR, False)
    if name in FIXED_LOOPS:
        a, b = FIXED_LOOPS[name]
        bar, score = 4 * 60 / bpm, float('nan')
        body = x[int(round(a * SR)):min(int(round(b * SR)), len(x))].copy()
    else:
        (score, a, b), bar = choose_loop(mono, 22050, bpm, ph, downbeat)
        ia, ib, n = int(round(a * SR)), int(round(b * SR)), int(round(bar * SR))
        body = x[ia:ib].copy()
        k = np.linspace(0.0, 1.0, n, dtype=np.float32)[:, None]
        body[-n:] = body[-n:] * np.cos(k * np.pi / 2) + x[ia - n:ia] * np.sin(k * np.pi / 2)
    rms = float(20 * np.log10(np.sqrt((body.astype(np.float64) ** 2).mean()) + 1e-9))
    body *= 10 ** ((TARGET_RMS - rms) / 20)
    peak = np.abs(body).max()
    # Never clip: lower the whole loop. 0.89 (-1 dBFS), not nearer 1.0 —
    # Vorbis overshoots on hard transients (the tombak loop's 0.97 master
    # decoded at 0.992).
    if peak > 0.89:
        body *= 0.89 / peak
    raw = OUT / f'{name}.f32'
    body.astype(np.float32).tofile(raw)
    subprocess.check_call(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '2',
                           '-i', str(raw), '-c:a', 'libvorbis', '-q:a', '6', str(OUT / f'{name}.ogg')])
    raw.unlink()
    a, b, bpm = float(a), float(b), float(bpm)
    info = dict(bpm=round(bpm, 2), loop_start=round(a, 3), loop_end=round(b, 3),
                loop_seconds=round(b - a, 3), bars=int(round((b - a) / bar)), seam_match=None if score != score else round(score, 3),
                fixed=name in FIXED_LOOPS,
                gain_db=round(TARGET_RMS - rms, 2))
    print(name, json.dumps(info))
    return info


if __name__ == '__main__':
    results = {name: master(name) for name in sys.argv[1:]}
    manifest_path = ROOT / 'assets/audio/elevenlabs_v2/manifest.json'
    manifest = json.loads(manifest_path.read_text())
    for name, info in results.items():
        manifest.setdefault('music', {}).setdefault(name, {})['loop'] = info
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
