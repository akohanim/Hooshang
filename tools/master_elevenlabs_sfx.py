#!/usr/bin/env python3
"""Master the generated sound effects into game-ready WAVs.

Same mastering as the earlier ElevenLabs cues (assets/audio/act2_elevenlabs):
mono 44.1 kHz 16-bit, leading silence trimmed at -45 dB, peak-normalized to
-3 dBFS, 3 ms attack / 25 ms release fades. A cue whose manifest entry has
`slices: N` was generated as N separate events with silence between them
(four footsteps, say); it is cut at its N strongest onsets into
<cue>_1.wav .. <cue>_N.wav, one variation each, so the game can avoid
repeating the same step twice in a row.

  python3 tools/master_elevenlabs_sfx.py [cue ...]   # default: every cue
"""
import json, subprocess, sys, wave
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / 'assets/audio/elevenlabs_v2'
SR = 44100
GATE_DB = -45.0
PEAK_DB = -3.0
MAX_SECONDS = {'crumble_warn': 0.6, 'crumble_break': 0.4, 'respawn': 0.45, 'step_scaffold': 0.35, 'step_stone': 0.3, 'step_grass': 0.3, 'ladder': 0.35, 'swim': 0.6,
               'jump': 0.35, 'land': 0.35, 'wall_jump': 0.18, 'splash': 0.8, 'crumble': 1.2,
               'checkpoint': 1.0, 'death': 0.6, 'darkshang_gather': 1.5, 'darkshang_lunge': 0.8}


def decode(name):
    """One source clip, by file stem (a `takes` cue's are <cue>_1 .. _N)."""
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(DIR / 'source' / f'{name}.mp3'),
                                   '-ac', '1', '-ar', str(SR), '-f', 'f32le', '-'])
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def envelope(x, win=441):
    return np.sqrt(np.convolve(x ** 2, np.ones(win) / win, 'same'))


def trim(x):
    gate = 10 ** (GATE_DB / 20) * np.abs(x).max()
    loud = np.nonzero(envelope(x) > gate)[0]
    return x[loud[0]:] if len(loud) else x


def finish(x, seconds):
    x = trim(x)[:int(seconds * SR)]
    x = x * 10 ** (PEAK_DB / 20) / (np.abs(x).max() + 1e-12)
    a, r = min(int(0.003 * SR), len(x) // 4), min(int(0.025 * SR), len(x) // 2)
    x[:a] *= np.linspace(0, 1, a)
    x[-r:] *= np.linspace(1, 0, r)
    return x


def slices(x, n):
    """The n strongest separate events: onsets of the smoothed envelope, at
    least 0.25 s apart, each cut up to the next onset."""
    env = envelope(x, 882)
    rise = np.maximum(np.diff(env, prepend=env[0]), 0)
    order = np.argsort(rise)[::-1]
    picks = []
    for i in order:
        if all(abs(i - p) > 0.25 * SR for p in picks):
            picks.append(i)
        if len(picks) == n:
            break
    picks = sorted(max(0, p - int(0.01 * SR)) for p in picks)
    return [x[p:(picks[k + 1] if k + 1 < len(picks) else len(x))] for k, p in enumerate(picks)]


def write(path, x):
    pcm = np.clip(x * 32767, -32768, 32767).astype('<i2')
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main():
    manifest = json.loads((DIR / 'manifest.json').read_text())
    wanted = sys.argv[1:]
    for name, cue in manifest['sfx'].items():
        if cue.get('unused') or (wanted and name not in wanted):
            continue
        n = int(cue.get('slices', 1))
        takes = int(cue.get('takes', 0))
        if takes:
            # `keep`: the takes chosen after measuring attack, length and
            # brightness (a late swell or a sparkle is rejected); default all.
            chosen = cue.get('keep', list(range(1, takes + 1)))
            parts = [decode(f'{name}_{k}') for k in chosen]
            n = len(chosen)
        else:
            x = decode(name)
            parts = slices(x, n) if n > 1 else [x]
        files = []
        for k, part in enumerate(parts, 1):
            out = DIR / (f'{name}_{k}.wav' if n > 1 else f'{name}.wav')
            y = finish(part, MAX_SECONDS[name])
            write(out, y)
            files.append(dict(file=out.name, seconds=round(len(y) / SR, 3)))
        cue['files'] = files
        print(name, [f['seconds'] for f in files])
    manifest['mastering'] = ('mono 44.1 kHz 16-bit; leading silence trimmed at -45 dB; peak -3 dBFS; '
                             '3 ms attack / 25 ms release; multi-event clips sliced at their strongest onsets')
    (DIR / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()
