"""Remove atlas cells below the installed banner's first complete tail."""
import json,subprocess
from pathlib import Path
from ldtk_preserve_json import update
from validate_prison_ldtk import validate
root=Path(__file__).resolve().parents[1];path=root/'ldtk/hooshang_act2.ldtk'
assert 'LDtk.app/Contents/MacOS/LDtk' not in subprocess.check_output(['ps','ax','-o','comm'],text=True),'Close LDtk first.'
raw=path.read_text();p=json.loads(raw)
for r in p['levels']:
 if not r['identifier'].startswith('Prison_Y'):continue
 layer=next(l for l in r['layerInstances'] if l['__identifier']=='CastleDecor')
 layer['gridTiles']=[t for t in layer['gridTiles'] if not (t['px'][0] in list(range(48,80,8))+list(range(240,272,8)) and t['px'][1] in (128,136,144) and t['src'][1]==t['px'][1])]
out=root/'output/act2_polish/prison_wings/banner_trim.ldtk';out.write_text(update(raw,p));validate(out);path.write_text(out.read_text())
