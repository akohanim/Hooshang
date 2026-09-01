#!/usr/bin/env python3
"""Generates the dialogue VOICE BLIPS -> assets/voice/<speaker>/<state>/*.wav

Celeste's own dialogue voice (see the design note this implements, a thread by
the game's sound designer) is not recorded speech: it is short synthesized
syllables built from vowel-like formants, banked per CHARACTER and per
EMOTIONAL STATE, and picked from at random as the text types out — quick
"passing" syllables most of the time, rarer "emphasized" ones, and a
"sentence-ending" one to close a line. That is the mechanism this rewrites;
there is no FMOD here and no audio designer manually riding a parametric EQ,
so the formant colouring below is synthesized directly rather than performed.

Pure stdlib (wave/struct/math/random), no numpy, matching gen_note_audio.py.
Deterministic: every clip's RNG is seeded from the string
"<speaker>:<state>:<tier>:<index>" — Python's random.seed() hashes a str
seed with sha512, which is stable run to run and interpreter to interpreter,
the same reproducibility rule tools/gen_thought_tiles.py and
DarkThought.reset_all() already depend on. Re-running this script regenerates
byte-identical files.

STATE NAMES ARE NOT INVENTED HERE — they are exactly scripts/act1_beats.gd's
FACES / RUMI_FACES keys (minus the four states that are aliases pointing at an
existing painting rather than states of their own). DialogueBox derives its
portrait-rig lookup key from the portrait texture's filename
("hooshang_annoyed", "rumi_wistful", ...) and systems/voice_blips.gd uses that
identical key for its voice pool, so nothing about how a beat is written
changes: a line that already names a state gets a voice for free.

FORMANT MODEL. A true formant synth filters a buzzy source through resonant
peaks; built instead as harmonic-weighted additive synthesis, which needs no
filter state per sample: each harmonic k*f0 of a sawtooth-ish source is
boosted by a Gaussian bump wherever it lands near one of two formant centres
(F1, F2), which are themselves interpolated between a DARK/closed vowel pair
and a BRIGHT/open one by each state's own `brightness`. That is what gives
each state a distinct vowel colour rather than every clip being the same bell
tone at a different pitch (compare gen_note_audio.py's tone(), which this
still borrows the envelope shape from). `formant_bw`/`formant_gain` are also
per-VOICE now (narrower + hotter reads as a sharper, more piercing resonance;
wider + gentler reads as warmer/rounder) — see VOICES.

CASTING. Hooshang is the PLAIN voice on purpose — the most generic man voice
this synthesis produces, no formant_bw/formant_gain override, no noise, mild
ordinary vibrato. Two earlier passes tried to give him more character
("sharper, unsure": a narrow/hot formant boost) and each correction chased the
last complaint into a new one (that boost read as a vocoder; damping it with
noise under the attack read as a snare hit) — he is left alone now rather than
sculpted further, and is the voice every other cast member gets judged as
different FROM. Rumi is still the deliberately cast exception: a base register
well BELOW Hooshang's at every state — checked directly, Rumi's brightest/
highest state never reaches Hooshang's darkest/lowest one — darker formants, a
slower and shallower vibrato (steady, not shaky), longer decay (sustain reads
as gravitas), and a quiet SUB-OCTAVE layer (`sub`) mixed under the main tone
purely for low-end chest weight, the "wise sage" register a plain low
fundamental alone doesn't quite sell.

Run from the repo root:  python3 tools/gen_voice_blips.py
"""
import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "voice")

RATE = 22050

# Two vowel-ish formant anchors (F1, F2 in Hz) a state's `brightness` (0..1)
# interpolates between: DARK is a closed/rounded vowel, BRIGHT an open one.
DARK = (320.0, 850.0)
BRIGHT = (700.0, 1350.0)
FORMANT_BW = 70.0        # default Gaussian half-width of a formant bump, Hz
FORMANT_GAIN = 2.2       # default how much louder a harmonic gets on-formant
HARMONICS = 10           # harmonics of f0 summed per clip (sawtooth falloff)
ATTACK_FLOOR = 0.002     # never a zero attack — avoids a click onset

# --- per-character base voice -----------------------------------------------
# base_freq: register — Rumi's sits well under Hooshang's, see the module
# docstring's CASTING note. jitter_semitones: default per-clip pitch spread.
# vibrato_(depth|rate): a wobble under the pitch. shimmer: a second, detuned
# copy of the carrier mixed under the first — chorus/richness. sub: Rumi
# only — a quiet sine an OCTAVE below f0 (fundamental only, no harmonics)
# mixed in purely for chest weight. formant_bw/formant_gain override the
# module defaults above; omitted entirely = plain (Hooshang, below).
# noise_amt: a touch of filtered noise under the attack, shaped to decay
# faster than the tone itself.
#
# HOOSHANG IS THE PLAIN VOICE, DELIBERATELY. Two earlier passes tried to make
# him distinctive — "sharper, unsure" (a narrow, hot formant boost) read as a
# vocoder, and fixing THAT by adding noise under the attack read as a snare
# hit under the tone. Both were reaching for character the synthesis wasn't
# built to carry cleanly. He is the one voice in this cast every OTHER voice
# gets judged as different FROM, so he is left at the module's own plain
# defaults (no formant_bw/formant_gain override, no noise, mild ordinary
# vibrato) rather than sculpted — "the most generic man voice" the synthesis
# can produce. Rumi is still the deliberately cast exception (deep, dark,
# steady, the sub-octave layer) since that one hasn't needed correcting.
VOICES = {
    "hooshang": dict(base_freq=125.0, jitter_semitones=1.2,
                      vibrato_depth=0.012, vibrato_rate=5.0, shimmer=False,
                      sub=0.0, noise_amt=0.0),
    "rumi":     dict(base_freq=82.0, jitter_semitones=0.8,
                      vibrato_depth=0.009, vibrato_rate=2.2, shimmer=True,
                      sub=0.32, formant_bw=100.0, formant_gain=1.6, noise_amt=0.0),
}

# How far apart two harmonics' starting phases can randomly land, radians.
# Perfectly phase-locked harmonics (phase 0 for every k, as a naive additive
# synth would have) sum to a mechanically clean, perfectly repeating
# waveform every cycle — audibly "buzzy" in the way a cheap synth or a
# vocoder is, rather than a voice, whose harmonics are never quite that
# coherent. Small on purpose: enough to break the lock-step, not enough to
# turn the harmonics into unrelated tones.
PHASE_JITTER = 0.35
# How much a clip's vowel colour (brightness) drifts from where it started
# to where it ends, as a fraction of the DARK..BRIGHT span. A held, perfectly
# static formant for the whole clip is the single biggest tell that a tone is
# synthesized rather than spoken — real speech is always moving through a
# vowel, never parked on one. Applied as a straight linear glide from a
# randomly chosen direction, not tied to any particular vowel shape (these are
# gibberish syllables, not real phonemes).
FORMANT_GLIDE = 0.22

# --- per-state modulation ----------------------------------------------------
# brightness: vowel colour, DARK(0)..BRIGHT(1). decay: exponential falloff
# rate (higher = shorter/snappier). attack: onset time, seconds. pitch_mult:
# scales the character's base_freq. jitter: this state's own pitch-spread
# multiplier on top of the voice's jitter_semitones.
#
# Hooshang's table stays MODERATE — an ordinary emotional range around the
# plain voice above, not pushed toward any extreme (see VOICES' note on why).
# Rumi skews DARK and slow-decaying across the board (deep, sustained,
# sage-like) — checked directly, Rumi's highest pitch_mult ("urgent", 1.08 *
# 82Hz = 88.6Hz) still lands well under Hooshang's lowest ("vulnerable",
# 0.92 * 125Hz = 115Hz), so Rumi reads deeper than Hooshang in EVERY state
# pairing, not just on average.
HOOSHANG_STATES = {
    "dazed":      dict(brightness=0.15, decay=9.0,  attack=0.010, pitch_mult=0.95, jitter=1.0),
    "hesitant":   dict(brightness=0.25, decay=10.0, attack=0.008, pitch_mult=1.00, jitter=1.5),
    "skeptical":  dict(brightness=0.35, decay=12.0, attack=0.006, pitch_mult=1.00, jitter=1.0),
    "annoyed":    dict(brightness=0.55, decay=14.0, attack=0.003, pitch_mult=1.08, jitter=2.5),
    "vulnerable": dict(brightness=0.10, decay=7.0,  attack=0.014, pitch_mult=0.92, jitter=1.0),
    "shocked":    dict(brightness=0.70, decay=16.0, attack=0.002, pitch_mult=1.20, jitter=3.0),
}
RUMI_STATES = {
    "serene":     dict(brightness=0.20, decay=4.0, attack=0.018, pitch_mult=1.00, jitter=1.0),
    "sorrowful":  dict(brightness=0.10, decay=3.4, attack=0.022, pitch_mult=0.92, jitter=1.0),
    "urgent":     dict(brightness=0.35, decay=8.5, attack=0.009, pitch_mult=1.08, jitter=1.8),
    "warm_open":  dict(brightness=0.32, decay=4.5, attack=0.015, pitch_mult=1.05, jitter=1.3),
    "wistful":    dict(brightness=0.16, decay=3.8, attack=0.020, pitch_mult=0.96, jitter=1.2),
}
STATES = {"hooshang": HOOSHANG_STATES, "rumi": RUMI_STATES}

# --- tiers: Celeste's "quick passing / emphasized / sentence-ending" -------
# Scaled down from Celeste's 20/10/10 syllable banks to a scope that fits a
# two-character cast. `falling`: a sentence-ending cadence drop in pitch
# across the clip, rather than a flat tone stopping.
TIERS = {
    "passing":    dict(count=8, dur=(0.055, 0.085), amp=0.30, extra_decay=1.00, pitch_bump=1.00, falling=False),
    "emphasized": dict(count=4, dur=(0.095, 0.135), amp=0.42, extra_decay=0.75, pitch_bump=1.12, falling=False),
    "ending":     dict(count=3, dur=(0.160, 0.240), amp=0.34, extra_decay=0.55, pitch_bump=1.00, falling=True),
}


def _formant_freqs(brightness):
    f1 = DARK[0] + (BRIGHT[0] - DARK[0]) * brightness
    f2 = DARK[1] + (BRIGHT[1] - DARK[1]) * brightness
    return f1, f2


def _harmonic_weight(freq, f1, f2, bw, gain):
    """1/k falloff (sawtooth-ish) plus a Gaussian boost near either formant."""
    boost = 0.0
    for fc in (f1, f2):
        boost += math.exp(-((freq - fc) / bw) ** 2)
    return 1.0 + gain * boost


def synth_clip(voice, state, tier, seed):
    rng = random.Random(seed)
    dur = rng.uniform(*tier["dur"])
    n = int(RATE * dur)
    bw = voice.get("formant_bw", FORMANT_BW)
    fgain = voice.get("formant_gain", FORMANT_GAIN)

    # The vowel colour GLIDES across the clip rather than sitting still — see
    # FORMANT_GLIDE's note. Direction is random per clip so a run of syllables
    # isn't all brightening (or all darkening) the same way.
    glide_dir = rng.choice((-1.0, 1.0))
    b_start = min(1.0, max(0.0, state["brightness"] - glide_dir * FORMANT_GLIDE * 0.5))
    b_end = min(1.0, max(0.0, state["brightness"] + glide_dir * FORMANT_GLIDE * 0.5))
    f1_start, f2_start = _formant_freqs(b_start)
    f1_end, f2_end = _formant_freqs(b_end)

    jitter_semitones = voice["jitter_semitones"] * state["jitter"]
    semis = rng.uniform(-jitter_semitones, jitter_semitones)
    f0 = voice["base_freq"] * state["pitch_mult"] * tier["pitch_bump"] * (2.0 ** (semis / 12.0))
    vib_phase0 = rng.uniform(0.0, 2.0 * math.pi)

    attack = max(state["attack"], ATTACK_FLOOR)
    decay_rate = state["decay"] * tier["extra_decay"]

    # Precompute each harmonic's weight at the START and END of the glide, its
    # own random phase offset (breaks the perfect phase-lock a naive additive
    # synth has — see PHASE_JITTER), and how many harmonics actually fit under
    # Nyquist. The SET of harmonics is fixed by f0 alone (unaffected by the
    # glide), only their weight moves.
    harmonics = []
    for k in range(1, HARMONICS + 1):
        if k * f0 * 2.2 >= RATE * 0.5:  # comfortably under Nyquist
            break
        w_start = (1.0 / k) * _harmonic_weight(k * f0, f1_start, f2_start, bw, fgain)
        w_end = (1.0 / k) * _harmonic_weight(k * f0, f1_end, f2_end, bw, fgain)
        phase = rng.uniform(-PHASE_JITTER, PHASE_JITTER)
        harmonics.append((k, w_start, w_end, phase))

    detune = 1.0 + rng.uniform(0.004, 0.009) if voice["shimmer"] else None
    sub = voice.get("sub", 0.0)
    noise_amt = voice.get("noise_amt", 0.0)
    # First-differenced white noise: a crude high-pass, so the breath/attack
    # texture sits as a hiss rather than a low rumble that would compete with
    # the tone (or, for Rumi, the sub-octave layer) for the same low end.
    prev_noise = 0.0

    out = []
    for i in range(n):
        t = i / RATE
        u = t / dur  # 0..1 across the clip
        fall = (1.0 - 0.28 * u) if tier["falling"] else 1.0
        vib = 1.0 + voice["vibrato_depth"] * math.sin(
            2.0 * math.pi * voice["vibrato_rate"] * t + vib_phase0)
        freq = f0 * fall * vib

        s = 0.0
        wsum = 0.0
        for k, w_start, w_end, phase in harmonics:
            w = w_start + (w_end - w_start) * u
            wsum += w
            s += w * math.sin(2.0 * math.pi * freq * k * t + phase)
        if detune is not None:
            for k, w_start, w_end, phase in harmonics:
                w = w_start + (w_end - w_start) * u
                s += 0.5 * w * math.sin(2.0 * math.pi * freq * detune * k * t + phase)
            wsum *= 1.5
        s /= wsum or 1.0
        if sub > 0.0:
            # An octave below f0, fundamental only — no harmonics needed for
            # a low chest tone, and adding the full stack down there would
            # just muddy the mix rather than add weight.
            s += sub * math.sin(2.0 * math.pi * (freq * 0.5) * t + vib_phase0 * 0.5)

        if noise_amt > 0.0:
            raw = rng.uniform(-1.0, 1.0)
            hp = (raw - prev_noise) * 0.5
            prev_noise = raw
            # Decays faster than the tone's own envelope, below — concentrates
            # the noise into the attack, the way a real onset has more breath/
            # consonant noise than its sustained vowel does.
            s += noise_amt * hp * math.exp(-decay_rate * 4.0 * t)

        env = min(1.0, t / attack) * math.exp(-decay_rate * t)
        out.append(s * env)

    peak = max((abs(v) for v in out), default=1.0) or 1.0
    gain = tier["amp"] / peak
    return [v * gain for v in out]


def write_wav(path, samples):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for v in samples:
            v = max(-1.0, min(1.0, v))
            frames += struct.pack("<h", int(v * 32767))
        w.writeframes(bytes(frames))


def main():
    manifest = {}
    total = 0
    for speaker, voice in VOICES.items():
        for state_name, state in STATES[speaker].items():
            key = "%s_%s" % (speaker, state_name)
            state_dir = os.path.join(OUT, speaker, state_name)
            os.makedirs(state_dir, exist_ok=True)
            manifest[key] = {}
            for tier_name, tier in TIERS.items():
                manifest[key][tier_name] = tier["count"]
                for i in range(1, tier["count"] + 1):
                    seed = "%s:%s:%s:%d" % (speaker, state_name, tier_name, i)
                    samples = synth_clip(voice, state, tier, seed)
                    dest = os.path.join(state_dir, "%s_%d.wav" % (tier_name, i))
                    write_wav(dest, samples)
                    total += 1
            print("wrote", key, {t: manifest[key][t] for t in TIERS})

    manifest_path = os.path.join(OUT, "manifest.json")
    import json
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)
        f.write("\n")
    print("wrote", os.path.relpath(manifest_path, ROOT))
    print("%d clips across %d voice/state keys" % (total, len(manifest)))


if __name__ == "__main__":
    main()
