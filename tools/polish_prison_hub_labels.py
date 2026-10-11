#!/usr/bin/env python3
"""Move wing labels into clear masonry space without changing routes or props."""
import copy,json,subprocess
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
root=Path(__file__).resolve().parents[1]
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
path=root/'ldtk/hooshang_act2.ldtk';raw=path.read_text();p=json.loads(raw);before=copy.deepcopy(p)
r=next(r for r in p['levels'] if r['identifier']=='Prison_Hub')
positions={'LIBRARY ^':([110,72],[48,72]),'< CAFETERIA':([54,120],[44,120]),'GYM >':([582,120],[590,136]),'BASEMENT v':([449,335],[449,320])}
labels={'LIBRARY ^':'LIBRARY UP','< CAFETERIA':'CAFETERIA','GYM >':'GYM','BASEMENT v':'BASEMENT DOWN'}
for layer in r['layerInstances']:
 for e in layer['entityInstances']:
  if e['__identifier']!='PrisonSign':continue
  label=next(f['__value'] for f in e['fieldInstances'] if f['__identifier']=='Text')
  if label not in positions:continue
  old,new=positions[label];assert e['px']==old,'Already changed; preserve authored edits'
  f=next(f for f in e['fieldInstances'] if f['__identifier']=='Text');f.update(__value=labels[label],realEditorValues=[dict(id='V_String',params=[labels[label]])])
  x,y=new;e.update(px=new,__grid=[x//8,y//8],__worldX=r['worldX']+x,__worldY=r['worldY']+y)
for a,b in zip(before['levels'],p['levels']):
 if a['identifier']!='Prison_Hub':assert a==b
out=root/'output/prison_challenge/hub';out.mkdir(parents=True,exist_ok=True)
(out/'before.ldtk').write_text(raw);preview=out/'preview.ldtk';preview.write_text(update(raw,p));validate(preview);path.write_text(preview.read_text())
