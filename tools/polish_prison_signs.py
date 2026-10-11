#!/usr/bin/env python3
"""Place concise mechanism instructions outside HUD and platform silhouettes."""
import copy,json,subprocess
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
root=Path(__file__).resolve().parents[1]
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
path=root/'ldtk/hooshang_act2.ldtk';raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
changes={'Prison_G01':(112,40,'TOUCH BOTH SEALS'),'Prison_G02':(160,40,'THREE SEALS'),'Prison_G03':(40,104,'FOUR SEALS'),'Prison_B03':(88,80,'TWO SEALS'),'Prison_R03':(184,40,'TWO SEALS')}
for r in p['levels']:
 if r['identifier'] not in changes:continue
 x,y,text=changes[r['identifier']]
 for l in r['layerInstances']:
  for e in l['entityInstances']:
   if e['__identifier']!='PrisonSign':continue
   e.update(px=[x,y],__grid=[x//8,y//8],__worldX=r['worldX']+x,__worldY=r['worldY']+y)
   f=next(f for f in e['fieldInstances'] if f['__identifier']=='Text');f.update(__value=text,realEditorValues=[dict(id='V_String',params=[text])])
for a,b in zip(before['levels'],p['levels']):
 if a['identifier'] not in changes:assert a==b
out=root/'output/prison_challenge/visual_cleanup';out.mkdir(parents=True,exist_ok=True)
assert not (out/'signs_before.ldtk').exists(),'Already authored; preserve later hand edits'
(out/'signs_before.ldtk').write_text(raw);preview=out/'signs_preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
