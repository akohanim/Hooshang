#!/usr/bin/env python3
"""Place Y03 upper completion and return controls on their clear supporting bank."""
import json,subprocess
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
root=Path(__file__).resolve().parents[1];path=root/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True)
raw=path.read_text();p=json.loads(raw)
r=next(r for r in p['levels'] if r['identifier']=='Prison_Y03')
es=next(l['entityInstances'] for l in r['layerInstances'] if l['__identifier']=='Entities')
for kind,old,new in [('TimedRelay',[104,56],[88,56]),('TimedLever',[80,56],[72,56])]:
 e=next(e for e in es if e['__identifier']==kind and e['px']==old)
 e.update(px=new,__grid=[new[0]//8,new[1]//8],__worldX=r['worldX']+new[0],__worldY=r['worldY']+new[1])
out=root/'output/prison_precision/gym_music/seal_bank.ldtk';out.write_text(update(raw,p));validate(out);path.write_text(out.read_text())
