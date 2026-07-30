#!/usr/bin/env python3
"""Turns raw oud recordings into the musical-tile notes -> assets/notes/note_N.wav

The five tiles are voiced by real oud samples (source recordings live outside
the repo). They cannot be dropped in untouched, because as recorded each file
opens with roughly a SECOND of silence before the pluck — stepping on a tile
would play nothing at all until long after Hooshang had walked off it. So:

  1. trim the lead-in, keeping a few ms of room tone before the attack so the
     pluck transient stays intact (chopping ON the transient makes it click);
  2. cap the tail, since an oud rings for 3-4s and five tiles hit in quick
     succession would otherwise smear into mush, with a short fade so the cut
     is inaudible;
  3. apply ONE shared gain to all five — shared, not per-file normalisation,
     so the relative balance of the performance is preserved exactly.

Order is positional: source file 1 -> note_1 (tile 1), 2 -> note_2, and so on.

The glow reward cue (success.wav) gets the same lead-in treatment via
--success, but keeps a QUARTER SECOND of silence rather than 20ms: it fires as
the fifth tile lights, and landing dead on that instant sounded like part of the
tile rather than a reward. Its tail is left alone — it is allowed to ring.

Run from the repo root:
    python3 tools/import_note_audio.py <src1.wav> ... <src5.wav>
    python3 tools/import_note_audio.py --success <harp.wav>
"""
import os
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "notes")

## Keep this much room tone ahead of the attack (seconds).
PRE_ROLL = 0.02
## Anything under this fraction of the file's peak counts as silence.
ONSET_FLOOR = 0.02
## Longest a note may ring after its attack (seconds).
MAX_TAIL = 2.0
## Fade applied to the last of that, so a capped tail doesn't click (seconds).
FADE_OUT = 0.25
## Loudest peak any note may reach, as a fraction of full scale.
TARGET_PEAK = 0.70
## Silence kept ahead of the glow reward cue. Longer than the notes' PRE_ROLL on
## purpose — see the --success note in the docstring.
SUCCESS_LEAD = 0.25


def read_wav(path):
    with wave.open(path) as w:
        ch, width, rate, n = (w.getnchannels(), w.getsampwidth(),
                              w.getframerate(), w.getnframes())
        if width != 2:
            raise SystemExit("%s: expected 16-bit, got %d-bit" % (path, width * 8))
        raw = w.readframes(n)
    return list(struct.unpack("<%dh" % (n * ch), raw)), ch, rate


def frame_peak(samples, ch, i):
    return max(abs(samples[i * ch + c]) for c in range(ch))


def onset_frame(samples, ch, peak):
    floor = peak * ONSET_FLOOR
    frames = len(samples) // ch
    for i in range(frames):
        if frame_peak(samples, ch, i) > floor:
            return i
    return 0


def process(path, rate_out=None):
    samples, ch, rate = read_wav(path)
    frames = len(samples) // ch
    peak = max(max(abs(s) for s in samples), 1)

    start = max(onset_frame(samples, ch, peak) - int(PRE_ROLL * rate), 0)
    end = min(frames, start + int((PRE_ROLL + MAX_TAIL) * rate))
    clip = samples[start * ch:end * ch]

    # Fade the tail so the cap is inaudible.
    fade = min(int(FADE_OUT * rate), (end - start))
    for k in range(fade):
        g = (fade - k) / fade
        i = (end - start - fade + k) * ch
        for c in range(ch):
            clip[i + c] = int(clip[i + c] * g)
    return clip, ch, rate, peak


def write_wav(path, samples, ch, rate):
    data = struct.pack("<%dh" % len(samples), *samples)
    with wave.open(path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data)


def install_success(path):
    """Trim the reward cue's lead-in to SUCCESS_LEAD, leaving the tail to ring.

    Idempotent: after a run the lead-in IS SUCCESS_LEAD, so a second run
    computes a cut of zero and leaves the file alone rather than eating into
    the attack.
    """
    samples, ch, rate = read_wav(path)
    frames = len(samples) // ch
    peak = max(max(abs(s) for s in samples), 1)
    onset = onset_frame(samples, ch, peak)
    start = max(onset - int(SUCCESS_LEAD * rate), 0)
    dest = os.path.join(OUT, "success.wav")
    write_wav(dest, samples[start * ch:], ch, rate)
    print("success.wav <- %-16s onset %.3fs, cut %.3fs, lead-in now %.3fs, %.2fs long" % (
        os.path.basename(path), onset / rate, start / rate,
        (onset - start) / rate, (frames - start) / rate))


def main(sources):
    if len(sources) == 2 and sources[0] == "--success":
        install_success(sources[1])
        return
    if len(sources) != 5:
        raise SystemExit(__doc__)
    clips = [process(p) for p in sources]

    # One shared gain, sized off the loudest of the five.
    loudest = max(max(abs(s) for s in c[0]) for c in clips)
    gain = (TARGET_PEAK * 32767.0) / loudest

    for i, (clip, ch, rate, src_peak) in enumerate(clips, start=1):
        out = [max(-32768, min(32767, int(s * gain))) for s in clip]
        dest = os.path.join(OUT, "note_%d.wav" % i)
        write_wav(dest, out, ch, rate)
        print("note_%d.wav  <- %-16s %.2fs, %dch %dHz, gain x%.2f" % (
            i, os.path.basename(sources[i - 1]),
            len(out) / ch / rate, ch, rate, gain))


if __name__ == "__main__":
    main(sys.argv[1:])
