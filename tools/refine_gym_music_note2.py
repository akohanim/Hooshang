#!/usr/bin/env python3
"""Separate Y03's second note from the deliberate upper-stone collapse path."""
import json,subprocess
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
root=Path(__file__).resolve().parents[1];path=root/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw)
r=next(r for r in p['levels'] if r['identifier']=='Prison_Y03')
e=next(e for l in r['layerInstances'] if l['__identifier']=='Entities' for e in l['entityInstances'] if e['__identifier']=='PrisonNote2')
assert e['px']==[240,80]
e.update(px=[264,88],__grid=[33,11],__worldX=r['worldX']+264,__worldY=r['worldY']+88)
out=root/'output/prison_precision/gym_music/note2_clearance.ldtk';out.write_text(update(raw,p));validate(out);path.write_text(out.read_text())
