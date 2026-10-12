#!/usr/bin/env python3
"""NOT CURRENTLY USED — the Darkshang theme is now a hand-made track ("Escape
From Homayun", see assets/audio/elevenlabs_v2/README.md). Kept because it
works for any drum bed + melody stem pair: it reads source/darkshang_theme_
layered_bed.mp3 only if you point SRC/names back at it.

Running it REPLACES assets/music/darkshang_theme.ogg, so it refuses unless
given --force.

Layer a melody stem over the Darkshang drum loop, with the balance set here.

Generated full mixes kept burying the melody: the tombak/darbuka-led take
measured ~43% percussive energy against ~6% melodic, and in play no santur
or kamancheh could be heard at all. Asking the generator again does not fix
a MIX. So the score is built from two generations:

  bed     source/darkshang_theme.mp3        drums-led (tombak, darbuka, daf)
  melody  source/darkshang_melody_stem.mp3  santur, kamancheh, ney, oud, drone,
                                            generated with no percussion

Both run at 120 BPM (measured). The bed's pitched content centres on B
(Homayun: B-C-D#...), the stem came back centred on C, so the stem is shifted
down one semitone, its beats are aligned to the bed's grid at the bar offset
whose onsets correlate best, and it is cut to the bed's own loop (same start
bar, same length) with the same one-bar equal-power seam. MELODY_DB sets
how far under the drums the melody sits; the sum is levelled to the other
scores' -17 dBFS RMS with a -1 dBFS ceiling.

  python3 tools/layer_darkshang_melody.py
Writes assets/music/darkshang_theme.ogg (replacing the bed-only loop) and
records the layering in assets/audio/elevenlabs_v2/manifest.json.
"""
import json, subprocess
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'assets/audio/elevenlabs_v2/source'
SR = 44100
BPM = 120.0
SEMITONES = -1          # stem C -> bed B
MELODY_DB = -4.0        # melody RMS relative to the bed's RMS
TARGET_RMS = -17.0
CEILING = 0.89


def decode(path, filters=None):
    cmd = ['ffmpeg', '-v', 'error', '-i', str(path)]
    if filters:
        cmd += ['-af', filters]
    cmd += ['-ac', '2', '-ar', str(SR), '-f', 'f32le', '-']
    return np.frombuffer(subprocess.check_output(cmd), dtype=np.float32).reshape(-1, 2).astype(np.float64)


def rms(x):
    return float(np.sqrt((x ** 2).mean()))


def onsets(x, hop=256):
    mono = x.mean(1)
    n = len(mono) // hop
    e = np.log(np.sqrt((mono[:n * hop].reshape(n, hop) ** 2).mean(1)) + 1e-5)
    return np.concatenate([[0], np.maximum(np.diff(e), 0)])


def main():
    import sys
    if '--force' not in sys.argv:
        raise SystemExit('Not in use: the Darkshang theme is the hand-made "Escape From Homayun". '
                         'Pass --force to overwrite it with the layered version.')
    manifest_path = ROOT / 'assets/audio/elevenlabs_v2/manifest.json'
    manifest = json.loads(manifest_path.read_text())
    loop = manifest['music']['darkshang_theme']['loop']
    a, b = loop['loop_start'], loop['loop_end']
    bed = decode(SRC / 'darkshang_theme.mp3')
    ratio = 2 ** (SEMITONES / 12)
    # Pitch only: resample down a semitone, then restore the tempo.
    mel = decode(SRC / 'darkshang_melody_stem.mp3',
                 f'asetrate={SR * ratio:.4f},aresample={SR},atempo={1 / ratio:.6f}')
    beat = 60.0 / BPM
    bar = 4 * beat
    # Align: try every offset of the stem against the bed's loop start in
    # beat-sized steps across a few bars, keep the best onset correlation.
    ob, om = onsets(bed), onsets(mel)
    fps = SR / 256
    span = int(32 * fps)
    ref = ob[int(a * fps):int(a * fps) + span]
    best = None
    for k in range(0, 16):                        # 16 beats = 4 bars of choice
        for fine in np.arange(-0.25, 0.25, 0.005):
            start = 2 * bar + k * beat + fine     # keep a bar of lead-in for the seam
            i = int(start * fps)
            seg = om[i:i + span]
            if len(seg) < span:
                continue
            score = float(np.corrcoef(ref, seg)[0, 1])
            if best is None or score > best[0]:
                best = (score, start)
    score, m0 = best
    length = b - a
    # No separate beat lock: the stem's oud band has no steady pulse at 120 BPM
    # (onset autocorrelation ~0 at the beat), so it is free-time texture —
    # tremolo, sustained phrases, drone — that cannot flam against the drums,
    # and a beat-phase 'lock' measured on it only chased noise. The
    # whole-band and oud-band correlations both pick this placement.
    ia, ib, n = int(round(a * SR)), int(round(b * SR)), int(round(bar * SR))
    im, imb = int(round(m0 * SR)), int(round((m0 + length) * SR))
    assert imb <= len(mel), 'melody stem is shorter than the loop'
    k = np.linspace(0, 1, n)[:, None]
    def seam(x, s, e):
        body = x[s:e].copy()
        body[-n:] = body[-n:] * np.cos(k * np.pi / 2) + x[s - n:s] * np.sin(k * np.pi / 2)
        return body
    drums = seam(bed, ia, ib)
    melody = seam(mel, im, imb)
    melody *= rms(drums) * 10 ** (MELODY_DB / 20) / rms(melody)
    mix = drums + melody
    mix *= 10 ** (TARGET_RMS / 20) / rms(mix)
    if np.abs(mix).max() > CEILING:
        mix *= CEILING / np.abs(mix).max()
    raw = ROOT / 'assets/music/darkshang_theme.f32'
    mix.astype(np.float32).tofile(raw)
    subprocess.check_call(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '2', '-i', str(raw),
                           '-c:a', 'libvorbis', '-q:a', '6', str(ROOT / 'assets/music/darkshang_theme.ogg')])
    raw.unlink()
    info = dict(melody_stem='source/darkshang_melody_stem.mp3', semitones=SEMITONES, bpm=BPM,
                melody_start=round(m0, 3), onset_correlation=round(score, 3), melody_db=MELODY_DB,
                loop_seconds=round(length, 3))
    manifest['music']['darkshang_theme']['layering'] = info
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(info))


if __name__ == '__main__':
    main()
