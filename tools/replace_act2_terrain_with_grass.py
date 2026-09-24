"""Replace Act 2 solid terrain with grass, preserving empty cells and water."""
import copy,json,shutil
from pathlib import Path
from act2_grass_terrain import rebake_layer,serialize_project
from ldtk_add_ceiling_tile import ldtk_running
ROOT=Path(__file__).resolve().parents[1]
assert not ldtk_running(), 'Close LDtk before changing the project'
path=ROOT/'ldtk/hooshang_act2.ldtk'
text=path.read_text();p=json.loads(text);before=copy.deepcopy(p)
backup=ROOT/'output/act2_grass_only';backup.mkdir(exist_ok=True)
(backup/'.gdignore').touch()
shutil.copy2(path,backup/'before.ldtk')
ld=next(l for l in p['defs']['layers'] if l['identifier']=='Collisions')
ld['intGridValues']=[v for v in ld['intGridValues'] if v['identifier']=='grass']
assert len(ld['intGridValues'])==1 and ld['intGridValues'][0]['value']==10
ld['autoRuleGroups']=[g for g in ld['autoRuleGroups'] if g['name'].startswith('grass /')]
rules=[r for g in ld['autoRuleGroups'] if g['active'] for r in g['rules'] if r['active']]
assert rules
count=0
for room in p['levels']:
    if room['identifier']=='Level_2':room['identifier']='Act_2_Level_2'
    for layer in room['layerInstances']:
        if layer['__identifier']!='Collisions':continue
        count+=sum(v!=0 for v in layer['intGridCsv'])
        layer['intGridCsv']=[10 if v else 0 for v in layer['intGridCsv']]
        layer['autoLayerTiles']=[]
        rebake_layer(layer,rules,{10:1})
        seen=set()
        for tile in layer['autoLayerTiles']:
            coord=tile['px'][0]//8+tile['px'][1]//8*layer['__cWid']
            assert tile['d'][1]==coord and len(tile['d'])==2
            assert coord not in seen and layer['intGridCsv'][coord]==10
            assert 739<=tile['t']<=933
            seen.add(coord)
        assert len(seen)==sum(v!=0 for v in layer['intGridCsv'])
for old,new in zip(before['levels'],p['levels']):
    for a,b in zip(old['layerInstances'],new['layerInstances']):
        if a['__identifier']=='Collisions':
            assert [bool(v) for v in a['intGridCsv']]==[bool(v) for v in b['intGridCsv']]
        else:assert a==b, 'Non-terrain layer changed'
path.write_text(serialize_project(text,p,before))
print(f'Converted {count} solid cells to grass. Water and all other layers unchanged.')
