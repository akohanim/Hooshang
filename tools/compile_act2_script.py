#!/usr/bin/env python3
"""Compile the archived author script to a portable Godot dialogue resource.

Reads docs/story/act2_author_script.md, which is Act Two of the author's
Markdown script ("Hooshang - The Script") pasted as-is:

    ## ONE — THE POND                    a scene heading
    *(Bright sun. A pond...)*            a stage direction: never a dialogue page
    **JAMSHID**                          a speaker
    *(unseen)*                           an acting note under the speaker: skipped
    Cousin joon!                         the one spoken line that block holds
    > HOLD ON                            on-screen text the scene draws itself

Markdown emphasis in a spoken line (*something*) is dropped rather than shown:
the dialogue box would print the asterisks.

Stage directions stay in the source document and are never dialogue pages.
Scenes that stage something between two lines find the line by its opening
words (Act2Script.cue), not by position, so adding or cutting a line elsewhere
in a scene cannot slide a beat onto the wrong words.
"""
import re, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HEADINGS = {
    'ONE — THE POND': 'pond',
    'TWO — THE CAMPFIRE': 'campfire',
    'THREE — DAWN': 'dawn',
    'FOUR — THE WALL': 'wall',
    'FIVE — THE PALACE OF CORRECTIONS': 'palace',
    'SIX — THE FOUR KEYS': 'keys',
    'SEVEN — THE CELL': 'cell',
    'EIGHT — THE CHASE': 'chase',
    'NINE — THE CARPET': 'carpet',
    'TEN — THE FALL': 'fall',
    'ELEVEN — THE BANK': 'bank',
    'TWELVE — THE SECOND LINE': 'second_line',
}
SPEAKER = re.compile(r"\*\*(HOOSHANG|JAMSHID'S MOTHER|JAMSHID|RUMI|OFFICER)\*\*")


def spoken(line: str) -> str:
    """The words as a player reads them: Markdown emphasis removed."""
    return re.sub(r"\*([^*]+)\*", r"\1", line).strip()


scenes = {}
scene = None
pending = None
for lineno, raw in enumerate((ROOT / 'docs/story/act2_author_script.md').read_text().splitlines(), 1):
    line = raw.strip()
    heading = line.lstrip('#').strip()
    if line.startswith('#') and heading in HEADINGS:
        scene = HEADINGS[heading]
        scenes[scene] = []
        pending = None
        continue
    speaker = SPEAKER.fullmatch(line)
    if speaker and scene:
        pending = speaker[1]
        continue
    # A direction under a speaker, a stage direction, a sign or a designer
    # note: none of them is something anybody says.
    if not line or line.startswith(('*(', '(', '>', '*[', '<!--', '-->')):
        continue
    if pending:
        scenes[scene].append({'speaker': pending, 'text': spoken(line), 'source_line': lineno})
        pending = None

missing = [k for k in HEADINGS.values() if k not in scenes]
assert not missing, f"scene headings not found: {missing}"
empty = [k for k, v in scenes.items() if not v]
assert not empty, f"scenes with no spoken lines: {empty}"
assert any(line['speaker'] == "JAMSHID'S MOTHER" for line in scenes['carpet'])
assert all('*' not in line['text'] for v in scenes.values() for line in v)

# Acting is maintained separately from the author's verbatim spoken text.
directions = json.loads((ROOT / 'resources/dialogue/act2_portrait_directions.json').read_text())
for chapter, entries in directions.items():
    available = list(entries)
    for line in scenes[chapter]:
        matches = [e for e in available if e['speaker'] == line['speaker'] and e['text'] == line['text']]
        if matches:
            entry = matches[0]
            line['face'] = entry['face']
            available.remove(entry)
    assert not available, f"Stale portrait directions in {chapter}: {available}"

out = ROOT / 'resources/dialogue/act2_author_script.tres'
out.write_text('[gd_resource type="Resource" script_class="Act2Script" load_steps=2 format=3]\n'
               '[ext_resource type="Script" path="res://resources/dialogue/act2_script.gd" id="1"]\n'
               '[resource]\nscript = ExtResource("1")\nscenes = '
               + json.dumps(scenes, ensure_ascii=False, indent=2) + '\n')
print({k: len(v) for k, v in scenes.items()})
