#!/usr/bin/env python3
"""Compile the archived author script to a portable Godot dialogue resource.
Stage directions stay in the source document and are never dialogue pages.
"""
import re,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
HEADINGS={'ONE — THE POND':'pond','TWO — THE CAMPFIRE':'campfire','THREE — DAWN':'dawn','FOUR — THE WALL':'wall','FIVE — THE PALACE OF CORRECTIONS':'palace','SIX — THE FOUR KEYS':'keys','ELEVEN — THE CELL':'cell','THIRTEEN — THE CARPET':'carpet','FIFTEEN — THE SECOND LINE':'second_line'}
scenes={};scene=None;pending=None
for lineno,line in enumerate((ROOT/'docs/story/act2_author_script.md').read_text().splitlines(),1):
    line=line.strip()
    if line in HEADINGS:
        scene=HEADINGS[line];scenes[scene]=[];pending=None;continue
    speaker=re.fullmatch(r"(HOOSHANG|Hooshang|JAMSHID'S MOTHER|JAMSHID|RUMI|OFFICER(?:/ PRINCIPAL)?)(?: \((.*)\))?",line)
    if speaker and scene:
        pending=speaker[1].upper().split('/')[0];continue
    if pending and line and not line.startswith('('):
        scenes[scene].append({'speaker':pending,'text':line,'source_line':lineno});pending=None
assert len(scenes)==9 and len(scenes['wall'])==27
assert sum(len(scenes[k]) for k in ['pond','campfire','dawn'])==41
assert any(line['speaker']=="JAMSHID'S MOTHER" for line in scenes['carpet'])
# Acting is maintained separately from the author's verbatim spoken text.
directions=json.loads((ROOT/'resources/dialogue/act2_portrait_directions.json').read_text())
for chapter,entries in directions.items():
    available=list(entries)
    for line in scenes[chapter]:
        matches=[e for e in available if e['speaker']==line['speaker'] and e['text']==line['text']]
        if matches:
            entry=matches[0];line['face']=entry['face'];available.remove(entry)
    assert not available, f"Stale portrait directions in {chapter}: {available}"
out=ROOT/'resources/dialogue/act2_author_script.tres'
out.write_text('[gd_resource type="Resource" script_class="Act2Script" load_steps=2 format=3]\n[ext_resource type="Script" path="res://resources/dialogue/act2_script.gd" id="1"]\n[resource]\nscript = ExtResource("1")\nscenes = '+json.dumps(scenes,ensure_ascii=False,indent=2)+'\n')
print({k:len(v) for k,v in scenes.items()})
for i,line in enumerate(scenes['wall']):print(i,line['speaker'],line['text'])
