#!/usr/bin/env python3
"""One visible vertical swim window; preserve the air-pocket recovery water."""
import copy,json,subprocess,uuid
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
root=Path(__file__).resolve().parents[1];path=root/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw)
r=next(r for r in p['levels'] if r['identifier']=='Prison_B02');es=next(l for l in r['layerInstances'] if l['__identifier']=='Entities')['entityInstances']
assert not any(e['__identifier']=='DarkThought' for e in es)
e=copy.deepcopy(next(e for rr in p['levels'] if rr['identifier'].startswith('Prison_') for l in rr['layerInstances'] for e in l['entityInstances'] if e['__identifier']=='DarkThought'))
e.update(iid=str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang/precision/b02/swim-patrol')),px=[144,112],__grid=[18,14],__worldX=r['worldX']+144,__worldY=r['worldY']+112)
for f in e['fieldInstances']:
 if f['__identifier'] in ['Motion','Amplitude','Speed','Phase']:
  v={'Motion':'Vertical','Amplitude':8.0,'Speed':0.3,'Phase':0.0}[f['__identifier']]
  f['__value']=v;f['realEditorValues']=[dict(id='V_String' if isinstance(v,str) else 'V_Float',params=[v])]
es.append(e)
out=root/'output/prison_precision/basement_stores';(out/'before_patrol.ldtk').write_text(raw)
preview=out/'patrol.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
