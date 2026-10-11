#!/usr/bin/env python3
"""Place the two story prefabs without changing any room geometry."""
import copy,json,uuid,subprocess
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
ROOT=Path(__file__).resolve().parents[1];path=ROOT/'ldtk/hooshang_act2.ldtk'
if 'LDtk.app/Contents/MacOS/LDtk' in subprocess.check_output(['ps','ax','-o','comm'],text=True):raise SystemExit('Close LDtk before editing.')
raw=path.read_text();p=json.loads(raw);defs=p['defs']['entities'];uid=p['nextUid']+1
if not any(d['identifier']=='Act2StoryScene' for d in defs):
    d=copy.deepcopy(next(d for d in defs if d['identifier']=='CastlePassage'))
    d.update(identifier='Act2StoryScene',uid=uid,width=288,height=104,pivotX=0,pivotY=1,doc='Author-script encounter: wall or palace. Completion persists.')
    d['fieldDefs'][0].update(identifier='Chapter',uid=uid+1)
    defs.append(d);p['nextUid']=uid+2
else:d=next(d for d in defs if d['identifier']=='Act2StoryScene')
r=next(r for r in p['levels'] if r['identifier']=='Act_2_Level_14');layer=next(a for a in r['layerInstances'] if a['__identifier']=='Entities')
for chapter,x in [('wall',0),('palace',496)]:
    iid=str(uuid.uuid5(uuid.NAMESPACE_URL,'hooshang-act2-story-'+chapter))
    if any(e['iid']==iid for e in layer['entityInstances']):continue
    field=dict(__identifier='Chapter',__type='String',__value=chapter,__tile=None,defUid=d['fieldDefs'][0]['uid'],realEditorValues=[dict(id='V_String',params=[chapter])])
    layer['entityInstances'].append(dict(__identifier=d['identifier'],__grid=[x//8,25],__pivot=[0,1],__tags=d['tags'],__tile=d['tileRect'],__smartColor=d['color'],iid=iid,width=288,height=104,defUid=d['uid'],px=[x,200],fieldInstances=[field],__worldX=r['worldX']+x,__worldY=r['worldY']+200))
out=ROOT/'output/act2_polish/milestone1/story_preview.ldtk';out.write_text(update(raw,p));validate(out)
backup=out.with_name('before_school_story.ldtk')
if not backup.exists():backup.write_text(raw)
path.write_text(out.read_text())
