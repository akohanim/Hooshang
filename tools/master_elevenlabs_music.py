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

Writes assets/music/<name>.ogg (and its .import's loop/loop_offset) and prints
the loop it chose; the result is also recorded in
assets/audio/elevenlabs_v2/manifest.json by the caller.

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
# Tracks that keep their generated opening as a one-time INTRO ahead of the
# loop. The file is head + loop, and the loop start is recorded as
# `loop_offset`, which goes into the .ogg.import: Godot jumps back there at the
# end, so the head plays once per play() and never again. The title screen's
# swell up out of silence suits a menu fading in; it would be wrong in a level.
INTRO = {'menu_theme'}
# Act III's way home is scored to its BEATS, not to rooms, so its cues keep their
# openings too: the sunrise swells up with the fade from black, the chase's
# first hit lands on the tiger's roar, and the tall grass and the vine start from
# their own quiet instead of mid-phrase. (scripts/act3/act3_music.gd.)
INTRO |= {'sea_sunrise', 'tiger_chase', 'tall_grass', 'vine_peril'}
SILENCE_DB = -60.0   # leading digital silence trimmed off an intro
# Which generated take a track is mastered from, where it is not its own name.
# The chase's first take came back bright with almost no low pulse; the second,
# drum-led take (tiger_chase_b) carries ~4 dB more below 160 Hz at the same
# 155 BPM gallop, and builds across its two minutes.
SOURCE = {'tiger_chase': 'tiger_chase_b'}
# Loudness per track where it is not TARGET_RMS: the stalking bed and the vine
# are underscore and sit well under the walking theme; the chase sits above it;
# the lemon is levelled over the whole piece, so its climax stays under the chase.
TARGETS = {'tall_grass': -23.0, 'vine_peril': -21.0, 'tiger_chase': -15.5, 'the_lemon': -18.0}
# Where the loop may start and by when it (and the two bars compared after it)
# must have ended, in seconds, where the default (the first five bars, up to the
# generated ending) is wrong, plus that track's shortest loop. The sunrise
# blooms from ~36 s and fades out from ~96 s: its quiet opening is the scene's
# one-time intro (he walks into the water, the carpet crosses the sun) and only
# the full middle loops, so a long stay never drops back to the swell.
LOOP_WINDOW = {'sea_sunrise': (30.0, 92.0, 44.0)}
# Seam crossfade, in bars, where one is not enough: the sunrise is rubato (no
# steady pulse at all by onset autocorrelation), so its seam is a blend of two
# textures rather than a cut on a downbeat, and a longer blend hides it.
XFADE_BARS = {'sea_sunrise': 2}
# The tempo, where the onset tracker reads it wrong. ElevenLabs renders at an
# exact BPM (measured: 92.00, 152.00, 60.00 by onset autocorrelation over the
# whole track), but the tracker's best score fell on 72.2 for the walking theme
# and 64.85 for the vine, and a loop measured in those "bars" is not a whole
# number of real ones: the seam would drop the walk's downbeat onto beat four
# and jump the vine's clock tick by a third of a second. The chase is counted in
# its 76 BPM half-time accents (6/8, two to a bar).
BPM = {'way_home': 92.0, 'vine_peril': 60.0, 'tiger_chase': 76.0}
# Tracks that are a PIECE, played once to their own end: no loop search, the
# whole generation from its first sound to its last, a short fade under the
# final note. The lemon is the end of the game.
ONESHOT = {'the_lemon'}


def decode(path, sr, mono):
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path), '-ac', '1' if mono else '2',
                                   '-ar', str(sr), '-f', 'f32le', '-'])
    a = np.frombuffer(raw, dtype=np.float32)
    return a if mono else a.reshape(-1, 2).copy()


def beat_grid(x, sr, bpms=None):
    hop = 64
    n = len(x) // hop
    e = np.log(np.sqrt((x[:n * hop].reshape(n, hop) ** 2).mean(1)) + 1e-5)
    on = np.concatenate([[0], np.maximum(np.diff(e), 0)])
    fps = sr / hop
    dur = len(x) / sr
    best = None
    for bpm in (np.arange(60, 180.01, 0.05) if bpms is None else bpms):
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
    # Length from `seconds` alone: int(start + seconds) - int(start) rounds to a
    # different sample count at different starts, and two fingerprints of
    # different lengths cannot be compared.
    i = int(start * sr)
    a = x[i:i + int(seconds * sr)].astype(np.float64)
    frames = a[:len(a) // 2048 * 2048].reshape(-1, 2048) * np.hanning(2048)
    spec = np.log(np.abs(np.fft.rfft(frames, axis=1))[:, 4:400] + 1e-4)
    spec -= spec.mean()
    return spec.ravel() / (np.linalg.norm(spec) + 1e-9)


def choose_loop(x, sr, bpm, ph, downbeat, window=None):
    beat = 60 / bpm
    bar = 4 * beat
    dur = len(x) / sr
    first = ph + downbeat * beat
    starts = np.arange(first, dur, bar)
    opens = starts[1:6]                        # skip the very first bar
    shortest = MIN_LOOP
    if window:
        lo, hi, shortest = window
        opens = starts[(starts >= lo) & (starts < lo + 5 * bar)]
        dur = min(dur, hi + TAIL_GUARD)
    best = None
    for a in opens:
        for b in starts:
            if b - a < shortest or b + 2 * bar > dur - TAIL_GUARD:
                continue
            with np.errstate(all="ignore"):  # spurious Accelerate matmul warnings on macOS
                score = float(fingerprint(x, sr, a, 2 * bar) @ fingerprint(x, sr, b, 2 * bar))
            if best is None or score > best[0]:
                best = (score, a, b)
    return best, bar


def master(name):
    src = SRC / f'{SOURCE.get(name, name)}.mp3'
    target = TARGETS.get(name, TARGET_RMS)
    mono = decode(src, 22050, True)
    bpm, ph, downbeat = beat_grid(mono, 22050, [BPM[name]] if name in BPM else None)
    x = decode(src, SR, False)
    if name in ONESHOT:
        return master_piece(name, x, target, bpm)
    if name in FIXED_LOOPS:
        a, b = FIXED_LOOPS[name]
        bar, score = 4 * 60 / bpm, float('nan')
        body = x[int(round(a * SR)):min(int(round(b * SR)), len(x))].copy()
    else:
        (score, a, b), bar = choose_loop(mono, 22050, bpm, ph, downbeat, LOOP_WINDOW.get(name))
        ia, ib, n = int(round(a * SR)), int(round(b * SR)), int(round(XFADE_BARS.get(name, 1) * bar * SR))
        body = x[ia:ib].copy()
        k = np.linspace(0.0, 1.0, n, dtype=np.float32)[:, None]
        body[-n:] = body[-n:] * np.cos(k * np.pi / 2) + x[ia - n:ia] * np.sin(k * np.pi / 2)
    # Level from the loop alone: a quiet intro would otherwise pull the gain up.
    rms = float(20 * np.log10(np.sqrt((body.astype(np.float64) ** 2).mean()) + 1e-9))
    offset = 0.0
    if name in INTRO:
        ia = int(round(a * SR))
        lead = int(np.argmax(np.abs(x[:ia]).max(1) > 10 ** (SILENCE_DB / 20)))
        lead = max(0, lead - int(0.01 * SR))
        body = np.concatenate([x[lead:ia], body])
        offset = (ia - lead) / SR
    body *= 10 ** ((target - rms) / 20)
    write_ogg(name, body)
    import_params(name, True, round(offset, 4))
    a, b, bpm = float(a), float(b), float(bpm)
    info = dict(bpm=round(bpm, 2), loop_start=round(a, 3), loop_end=round(b, 3),
                loop_seconds=round(b - a, 3), bars=int(round((b - a) / bar)), seam_match=None if score != score else round(score, 3),
                fixed=name in FIXED_LOOPS, source=SOURCE.get(name, name),
                gain_db=round(target - rms, 2))
    if name in INTRO:
        info['loop_offset'] = round(offset, 4)
    print(name, json.dumps(info))
    return info


def master_piece(name, x, target, bpm):
    """A ONESHOT: the generation from its first sound to its last, levelled over
    the whole piece, with a half-second fade so the final note cannot click."""
    loud = np.abs(x).max(1) > 10 ** (SILENCE_DB / 20)
    first = max(0, int(np.argmax(loud)) - int(0.01 * SR))
    last = len(loud) - int(np.argmax(loud[::-1]))
    body = x[first:last].copy()
    fade = min(len(body), int(0.5 * SR))
    body[-fade:] *= np.cos(np.linspace(0.0, np.pi / 2, fade, dtype=np.float32))[:, None]
    rms = float(20 * np.log10(np.sqrt((body.astype(np.float64) ** 2).mean()) + 1e-9))
    body *= 10 ** ((target - rms) / 20)
    write_ogg(name, body)
    import_params(name, False, 0.0)
    info = dict(oneshot=True, bpm=round(float(bpm), 2), start=round(first / SR, 3),
                seconds=round(len(body) / SR, 3), source=SOURCE.get(name, name), gain_db=round(target - rms, 2))
    print(name, json.dumps(info))
    return info


def write_ogg(name, body):
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


def import_params(name, loop, offset):
    """Write `loop` and `loop_offset` into the .ogg.import (by hand, before this
    did it): an intro's head plays once because Godot jumps back to the offset.
    A file Godot has not imported yet gets the minimal .import it fills in."""
    path = OUT / f'{name}.ogg.import'
    if not path.exists():
        path.write_text('[remap]\n\nimporter="oggvorbisstr"\ntype="AudioStreamOggVorbis"\n\n[params]\n\n'
                        f'loop={str(loop).lower()}\nloop_offset={offset}\nbpm=0\nbeat_count=0\nbar_beats=4\n')
        return
    lines = []
    for line in path.read_text().splitlines():
        if line.startswith('loop='):
            line = f'loop={str(loop).lower()}'
        elif line.startswith('loop_offset='):
            line = f'loop_offset={offset}'
        lines.append(line)
    path.write_text('\n'.join(lines) + '\n')


if __name__ == '__main__':
    results = {name: master(name) for name in sys.argv[1:]}
    manifest_path = ROOT / 'assets/audio/elevenlabs_v2/manifest.json'
    manifest = json.loads(manifest_path.read_text())
    for name, info in results.items():
        manifest.setdefault('music', {}).setdefault(name, {})['loop'] = info
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
