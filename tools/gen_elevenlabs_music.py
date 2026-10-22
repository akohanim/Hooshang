#!/usr/bin/env python3
"""Generate the game's ElevenLabs Music tracks.

Prompts live in MUSIC below and are copied into
assets/audio/elevenlabs_v2/manifest.json with the settings used, the same way
gen_elevenlabs_sfx.py records its cues. Raw MP3s go to .../source/ (hidden from
Godot by .gdignore); tools/master_elevenlabs_music.py then turns one into a
looped, levelled assets/music/<name>.ogg.

The API key is read from XI_API_KEY, or failing that from
~/.config/elevenlabs/api_key, and is never written anywhere.

  python3 tools/gen_elevenlabs_music.py menu_theme
  python3 tools/master_elevenlabs_music.py menu_theme
"""
import json, os, sys, urllib.error, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / 'assets/audio/elevenlabs_v2'
KEY_FILE = Path.home() / '.config/elevenlabs/api_key'
MODEL = 'music_v2_5'
NO_EXTRA = (' Consistent energy throughout with no big intro, build, breakdown or ending,'
            ' so it loops cleanly. No vocals.')

MUSIC = {
    # The title screen. Warm and quiet by direction: the previous menu cue was
    # stripped down to a soft bed with a darbuka hit twice a phrase, after a
    # tombak pulse and an eerie melody stem were turned down. The ney is Rumi's
    # own instrument — the Masnavi opens with the reed's lament — so it carries
    # the tune.
    'menu_theme': dict(seconds=120, prompt=(
        'Instrumental title-screen theme for a 2D pixel-art platformer about Hooshang, an elderly '
        'Iranian office worker who escapes a dark corporate office and rediscovers the warmth of '
        'his childhood in Iran, guided by the poet Rumi. Warm, nostalgic and hopeful, bittersweet '
        'but never eerie, dark or scary. A breathy ney reed flute carries a simple, memorable, '
        'singable melody in Persian Dashti colour (from dastgah Shur), over gently rolling santur '
        'arpeggios and soft setar plucks, with a warm low string pad underneath. Only a few soft '
        'daf frame-drum touches, no driving percussion and no tombak. Slow, calm, unhurried tempo '
        'around 76 BPM, steady pulse.')),

    # ACT III, THE WAY HOME (SCRIPT.md TEN to THIRTEEN; scripts/act3/act3_music.gd).
    # One arc across seven rooms, and the end of the whole game. The sea's score
    # under the water was synthesised; up here everything is ACOUSTIC for the
    # first time, the real world in colour. The ney is Rumi's reed and the title
    # theme's voice, so the homecoming and the lemon sing in its Dashti colour and
    # the game ends where it began; the tiger is Homayoun, the same parent mode
    # turned to menace, so the chase is the homecoming's shadow, not a stranger.
    # Silence is scored too: the growl, the "...No." and the fall land in it.

    # TEN: the real sea at sunrise. The release. Its opening swell is kept as a
    # one-time intro (master INTRO): it rises with the fade from black.
    'sea_sunrise': dict(seconds=110, tail=(
        ' After that opening, consistent energy with no further build, breakdown or ending,'
        ' so it loops cleanly. No vocals.'), prompt=(
        'Instrumental cinematic score for the moment an old Iranian man, after a long dark journey under '
        'the sea, walks out of his office at dawn and stands barefoot in the real sea at sunrise. '
        'Overwhelming quiet joy and release, tender and luminous, tears of relief: the first real '
        'daylight in the whole game. A breathy ney reed flute sings a long, simple, singable homecoming '
        'melody in Persian Dashti colour (from dastgah Shur), over shimmering santur arpeggios like '
        'sunlight glittering on water, a slow-blooming warm string orchestra, soft sustained horns and a '
        'low warm pad, with gentle swells like waves. No drums except a few soft, distant daf touches. '
        'Slow, around 66 BPM, spacious and unhurried. It begins with a slow warm swell rising out of '
        'silence over the first few seconds, then settles into the melody at a steady, glowing level.')),

    # ELEVEN: the shore road and the high meadow. Nothing chases him.
    'way_home': dict(seconds=110, prompt=(
        'Instrumental walking theme for a 2D pixel-art platformer: an elderly Iranian man walks home '
        'along a sunny shore road and up into a high meadow of poppies above the sea, free at last, with '
        'nothing chasing him. Light, unhurried, content and quietly happy, a gentle morning stroll in '
        'sunlight and sea breeze; pastoral but never childish or cartoonish. A setar plucks a lilting, '
        'memorable Persian folk melody in dastgah Mahur, answered by a warm kamancheh countermelody; '
        'light pizzicato strings and soft santur keep a walking pulse; a gentle daf and tombak play a '
        'relaxed, swaying groove; now and then a bright ney flourish like birdsong. Walking tempo around '
        '92 BPM, steady pulse.')),

    # TWELVE, before the roar: the tall grass, where the wind stops.
    'tall_grass': dict(seconds=90, prompt=(
        'Instrumental suspense underscore for a 2D game: walking into tall grass where the wind has '
        'suddenly stopped and something unseen is watching from very close. Still, airless and uneasy, '
        'quiet but full of dread: a predator stalking. Sustained high string harmonics over a cold low '
        'string drone, a single low setar note plucked every few seconds with long silence around it, '
        'breathy ney air with no melody, soft rustling textures, and a slow, faint, distant frame-drum '
        'heartbeat. Persian dastgah Homayoun colour. Almost no rhythm, very sparse, around 60 BPM, low '
        'volume throughout, never building to a climax.')),

    # TWELVE: the tiger, from its roar to the edge. The opening hit is kept as a
    # one-time intro (master INTRO), landing on the roar.
    'tiger_chase': dict(seconds=120, tail=(
        ' It opens instantly at full intensity on one huge drum-and-low-brass hit, with no fade-in and'
        ' no slow build, then holds that relentless driving intensity for the whole length with no'
        ' breakdown, no quiet passage and no ending, so it loops cleanly. No vocals.'), prompt=(
        'Instrumental cinematic action chase cue for a 2D pixel-art platformer: a tiger is hunting an old '
        'man through a forest and over cliff-top rocks, always one breath behind him. Primal, ferocious, '
        'relentless and breathless: you are prey running for your life. Persian war-drum fury meets epic '
        'film score: thundering low dohol and huge frame drums pounding like a big cat\'s paws in a fast '
        'galloping 6/8, rapid tombak rolls and finger strikes, a string section and kamancheh sawing '
        'fierce fast ostinatos, a tar strummed hard and aggressive, low brass snarling on the off-beats '
        'like a growl, and piercing ney shrieks at the ends of phrases. Persian dastgah Homayoun, dark '
        'and urgent. Fast, around 152 BPM.')),

    # A second take of the chase, led by the DRUMS: the first came back bright,
    # the strings sawing at 155 BPM but almost no low pulse under them, and a
    # tiger is weight. master_elevenlabs_music.py's SOURCE picks the take.
    'tiger_chase_b': dict(seconds=120, tail=(
        ' It opens instantly at full intensity on one huge drum-and-low-brass hit, with no fade-in and'
        ' no slow build, then holds that relentless driving intensity for the whole length with no'
        ' breakdown, no quiet passage and no ending, so it loops cleanly. No vocals.'), prompt=(
        'Instrumental cinematic action chase cue for a 2D pixel-art platformer: a tiger is hunting an old '
        'man through a forest and over cliff-top rocks, always one breath behind him. Driven above all by '
        'DRUMS: massive low dohol and big frame drums hammering a galloping 6/8 rhythm like a charging '
        'tiger\'s paws, deep booming hits on every downbeat, rapid tombak rolls and stomping low toms; a '
        'heavy low cello and double-bass ostinato and growling low brass underneath; kamancheh and tar '
        'slashing fast Persian phrases on top; short piercing ney shrieks. Dark, heavy, ferocious and '
        'primal, low and powerful rather than bright: you are prey running for your life. Persian '
        'dastgah Homayoun. Fast, around 152 BPM.')),

    # THIRTEEN: on the vine, a tiger above and below, the mice at the root.
    'vine_peril': dict(seconds=90, prompt=(
        'Instrumental underscore for a frozen moment of peril: an old man hangs from a single vine on a '
        'cliff face, a hungry tiger waiting above and another pacing below, while two mice slowly gnaw '
        'through the vine. Suspended, quiet and tense, yet strangely still, as if time has stopped. A '
        'very low sustained cello and double-bass drone, a slow, soft heartbeat on a low frame drum, a '
        'dry, steady high pizzicato tick like a clock, faint airy ney breaths and a distant cold string '
        'harmonic. Persian dastgah Homayoun colour. Slow, around 60 BPM, very sparse and restrained, low '
        'volume, no real melody and no climax.')),

    # THIRTEEN: the lemon. A one-shot PIECE (master ONESHOT), the end of the
    # game: it starts as he picks it and carries the end cards and the results.
    'the_lemon': dict(seconds=100, tail=' No vocals.', prompt=(
        'Instrumental finale for the last moment of a game: an old man hanging from a vine between two '
        'tigers picks a lemon growing from the cliff, tastes it, and for the first time in his life is '
        'completely present. Tender, sweet, grateful and quietly radiant: peace in the middle of danger, '
        'the end of the whole story. It begins from near silence with a solo breathy ney reed flute '
        'singing a simple, aching homecoming melody in Persian Dashti colour (from dastgah Shur). After '
        'about fifteen seconds a gentle santur joins with soft rolling arpeggios, then a setar. After '
        'about forty seconds a warm string orchestra blooms underneath and the melody rises to a full, '
        'heartfelt, glowing climax around the one-minute mark, never loud or bombastic. Then everything '
        'thins back down to the ney and santur alone, and the piece ends on a long, peaceful held note '
        'that fades to silence. Slow and rubato, around 64 BPM. No percussion except a few very soft daf '
        'touches near the climax.')),
}


def api_key():
    key = os.environ.get('XI_API_KEY', '').strip()
    if not key and KEY_FILE.exists():
        key = KEY_FILE.read_text().strip()
    if not key:
        sys.exit(f'No ElevenLabs key: set XI_API_KEY or write it to {KEY_FILE}')
    return key


def generate(name, spec, key):
    body = dict(prompt=spec['prompt'] + spec.get('tail', NO_EXTRA), music_length_ms=int(spec['seconds'] * 1000),
                model_id=MODEL, force_instrumental=True)
    req = urllib.request.Request('https://api.elevenlabs.io/v1/music?output_format=mp3_44100_192',
                                 data=json.dumps(body).encode(),
                                 headers={'xi-api-key': key, 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            (DIR / 'source' / f'{name}.mp3').write_bytes(r.read())
    except urllib.error.HTTPError as e:
        sys.exit(f'{name}: HTTP {e.code} {e.read().decode(errors="replace")[:500]}')
    return body


def main():
    key = api_key()
    manifest_path = DIR / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    tracks = manifest.setdefault('music', {})
    for name in sys.argv[1:] or [n for n in MUSIC if not (DIR / 'source' / f'{n}.mp3').exists()]:
        request = generate(name, MUSIC[name], key)
        tracks.setdefault(name, {})['request'] = request
        print(name, '->', DIR / 'source' / f'{name}.mp3')
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()
