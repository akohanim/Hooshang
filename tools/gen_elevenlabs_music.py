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
}


def api_key():
    key = os.environ.get('XI_API_KEY', '').strip()
    if not key and KEY_FILE.exists():
        key = KEY_FILE.read_text().strip()
    if not key:
        sys.exit(f'No ElevenLabs key: set XI_API_KEY or write it to {KEY_FILE}')
    return key


def generate(name, spec, key):
    body = dict(prompt=spec['prompt'] + NO_EXTRA, music_length_ms=int(spec['seconds'] * 1000),
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
