#!/usr/bin/env python3
"""Generate the game's ElevenLabs sound effects (Sound Effects v2).

Prompts live in SFX below and are copied into
assets/audio/elevenlabs_v2/manifest.json with the settings used, so every cue
can be regenerated or re-mastered. Raw MP3s go to .../source/. The API key is
read from the XI_API_KEY environment variable and is never written anywhere.

  XI_API_KEY=... python3 tools/gen_elevenlabs_sfx.py [cue ...]   # default: all missing
"""
import json, os, sys, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / 'assets/audio/elevenlabs_v2'
NO_EXTRA = ' Dry close recording, no music, no voices, no background ambience.'
# `slices`: the prompt asks for N separate events with silence between them;
# master_elevenlabs_sfx.py cuts them apart into N variations of one cue. That
# only works when the model actually delivers N even events (grass and swim
# did; scaffold, stone and ladder came back as one hit and a tail), so those
# use `takes`: N separate single-event generations, <cue>_1.mp3 .. _N.mp3.
SFX = {
    'step_scaffold': dict(takes=4, seconds=0.5, text='One single footstep of a light leather shoe on a hollow steel scaffolding grate: a short metallic clank with a faint ring.'),
    'step_stone': dict(takes=4, seconds=0.5, text='One single footstep of a soft leather shoe on an old stone castle floor: a gentle tap and scuff.'),
    'step_grass': dict(slices=4, seconds=3.0, text="Four separate single footsteps of a small child's light sandals on soft garden grass and earth, each a gentle soft rustle, evenly spaced with clear silence between each step."),
    'ladder': dict(takes=4, seconds=0.5, text='One single climbing step on a metal ladder: a short dull metallic clunk of a hand and shoe gripping a steel rung.'),
    'swim': dict(slices=3, seconds=3.0, text='Three separate gentle swimming strokes in calm pond water, each a soft paddling splash, evenly spaced with clear silence between each stroke.'),
    'jump': dict(seconds=0.5, text='A single quick light jump: a soft cloth whoosh and a shoe pushing off the ground, very short.'),
    'land': dict(seconds=0.5, text='A single soft landing thud of a small person landing on their feet after a short hop, light cloth rustle, very short.'),
    # Wall jumps CHAIN — up a chimney he kicks every few tenths of a second — so
    # this is a tight soft scuff with no whoosh: the first pass's airy whoosh
    # swelled to its peak 75 ms after the kick and, one take repeated, read as
    # the same hiss lagging every kick. Several takes so a climb never repeats.
    'wall_jump': dict(takes=6, seconds=0.5, text='One single soft quick push-off of a shoe sole against a brick wall: a short muted scuff with a tiny cloth flick, tight and dry, starting instantly and over in a fraction of a second. Gentle and understated, no whoosh tail, no impact boom.'),
    'splash': dict(seconds=0.8, text='A small person dropping into a garden pond: one short soft water splash.'),
    # The crumble is TWO cues, timed to crumbling_platform.gd: a rattle that
    # starts the instant he lands (crumble_time 0.6 s of jitter) and the break
    # when the blocks actually drop. The first pass was one 1.2 s swell whose
    # crack arrived late, so it never lined up with what you see.
    'crumble_warn': dict(takes=3, seconds=0.7, text='Small loose stone blocks shifting under weight: a quick dry gritty rattle and scrape of stones grinding together, starting immediately and steady for half a second.'),
    'crumble_break': dict(takes=3, seconds=0.5, text='A few small stone bricks breaking apart and dropping away: one crisp dry crack immediately followed by a short clatter of falling pebbles.'),
    'checkpoint': dict(seconds=1.0, text='A warm gentle checkpoint chime for a cozy platformer: two soft rising plucked santur notes with a little shimmer, short.'),
    # Nearly every death is a THOUGHT (clouds, thought tiles, the thorn
    # thickets are ink thoughts): the dark cloud swallowing him. The first pass
    # was a sparkly shimmer; this deep muffled "oom" is the one kept. A bright
    # Celeste-style burst was tried and turned down in favour of it, and the
    # separate respawn breath was dropped (it landed half a second after the
    # death and read as the death sound arriving late).
    'death': dict(takes=3, seconds=0.6, text="A soft muffled whump as a small dark storm cloud swallows someone: a quick low airy puff, like a pillow-muffled balloon pop, dissolving into a short breathy whoosh. Gentle, not violent, no shimmer, no sparkle, no chime."),
    'darkshang_gather': dict(seconds=1.5, text='A dark ominous inhale gathering into a low rumbling swell: a living storm-cloud shadow drawing itself together before it lunges.'),
    'darkshang_lunge': dict(seconds=0.8, text='A fast heavy dark whoosh of smoky wind rushing past at speed, with a low rumble.'),
}


def generate(name, spec):
    body = dict(text=spec['text'] + NO_EXTRA, duration_seconds=spec['seconds'], prompt_influence=0.6,
                model_id='eleven_text_to_sound_v2')
    req = urllib.request.Request('https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_192',
                                 data=json.dumps(body).encode(),
                                 headers={'xi-api-key': os.environ['XI_API_KEY'], 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=300) as r:
        (DIR / 'source' / f'{name}.mp3').write_bytes(r.read())
    return body


def main():
    (DIR / 'source').mkdir(parents=True, exist_ok=True)
    manifest_path = DIR / 'manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    manifest.setdefault('provider', 'ElevenLabs')
    manifest.setdefault('plan', 'starter (commercial license)')
    cues = manifest.setdefault('sfx', {})
    wanted = sys.argv[1:] or [n for n in SFX if not (DIR / 'source' / f'{n}.mp3').exists()
                              and not (DIR / 'source' / f'{n}_1.mp3').exists()]
    for name in wanted:
        spec = SFX[name]
        takes = spec.get('takes', 0)
        if takes:
            request = [generate(f'{name}_{k}', spec) for k in range(1, takes + 1)][0]
            old = DIR / 'source' / f'{name}.mp3'
            if old.exists():
                old.unlink()
        else:
            request = generate(name, spec)
        cues[name] = dict(request=request, slices=spec.get('slices', 1), takes=takes)
        print('generated', name)
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()
