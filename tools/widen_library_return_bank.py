#!/usr/bin/env python3
"""Widen G01's permanent upper bank, keeping its challenge-facing edge fixed."""
import json,subprocess
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
root=Path(__file__).resolve().parents[1];path=root/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw)
r=next(r for r in p['levels'] if r['identifier']=='Prison_G01');ls={l['__identifier']:l for l in r['layerInstances']}
rule=next(a for d in p['defs']['layers'] if d['identifier']=='Tiles' for g in d['autoRuleGroups'] for a in g['rules'] if a['pattern']==[2]);tile=rule['tileRectsIds'][0][0]
for x in [36,37,38]:
 i=8*40+x
 assert ls['Collision']['intGridCsv'][i]==0,'Inspect existing bank; do not overwrite later edits.'
 ls['Collision']['intGridCsv'][i]=2
 ls['Tiles']['autoLayerTiles'].append(dict(px=[x*8,64],src=[tile%16*8,tile//16*8],t=tile,f=0,a=1,d=[rule['uid'],i]))
out=root/'output/prison_precision/library_intro';(out/'before_return_bank.ldtk').write_text(raw)
preview=out/'return_bank.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
