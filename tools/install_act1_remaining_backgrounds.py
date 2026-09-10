"""Install room art without changing the authored eclipse/dawn lighting nodes."""
from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[1]
art = ROOT / 'assets/background/act1_office'
scene = ROOT / 'ldtk/Act1World.tscn'
rows = json.loads((art / 'remaining_rooms.json').read_text())
s = scene.read_text()
if 'id="office_Level_10"' in s:
    raise SystemExit('Remaining backgrounds already installed')
resources = '\n'.join(f'[ext_resource type="Texture2D" path="res://assets/background/act1_office/{r["room"].lower()}.png" id="office_{r["room"]}"]' for r in rows)
s = s.replace('[node name="Act1World"', resources + '\n\n[node name="Act1World"', 1)
entries = ',\n'.join(f'"{r["room"]}": ExtResource("office_{r["room"]}")' for r in rows)
s = s.replace('"Level_9": ExtResource("office_9")', '"Level_9": ExtResource("office_9"),\n' + entries, 1)
s = s.replace('room_moon_regions =', 'room_backdrop_tints = Dictionary[String, Color]({\n"Level_10": Color(0.34, 0.46, 0.6, 1),\n"Level_11": Color(0.28, 0.4, 0.56, 1),\n"Level_V3": Color(0.32, 0.42, 0.55, 1),\n"Level_V_test": Color(0.5, 0.6, 0.7, 1),\n"TEST": Color(0.55, 0.65, 0.75, 1)\n})\n\n' + 'room_moon_regions =', 1)
world = json.loads((ROOT / 'ldtk/hooshang_act1.ldtk').read_text())
rooms = {r['identifier']: r for r in world['levels']}
blocks = []
# Rooms whose original scene had no window. Dark puzzle rooms deliberately
# receive none, and the existing eclipse/return/dawn fixtures stay untouched.
for name in ['Level_V1', 'Level_V2', 'Level_V3', 'Level_V4', 'Level_v5', 'Level_v6', 'Level_V_test', 'TEST', 'Level_22', 'Level_23']:
    room = rooms[name]
    w,h=room['pxWid'], room['pxHei']
    points = [(x, 64) for x in range(128, w-24, 256)] if w > 300 else [(w//2, y) for y in range(80, h-24, 160)]
    if name == "Level_23":
        points = [(244, 64)]  # clear of the two tall gameplay pillars
    for i,(x,y) in enumerate(points):
        tag=f'OfficeWindow_{name}_{i}'
        warm = name in ('Level_22', 'Level_23')
        color = 'Color(0.99, 0.57, 0.35, 1)' if name == 'Level_22' else 'Color(1, 0.6, 0.37, 1)'
        extra = ''
        if warm:
            extra = '\nmoon_color = '+color+'\nsky_color = Color(0.198, 0.093, 0.13, 1)\nshadow_amount = '+('0.14' if name=='Level_22' else '0.09')+'\nhalo_color = '+color+'\nhalo_amount = 0.4'
        blocks.append(f'[node name="{tag}" parent="Backdrop" instance=ExtResource("8_moon")]\nposition = Vector2({room["worldX"]+x}, {room["worldY"]+y}){extra}\n')
        blocks.append(f'[node name="{tag}Pool" parent="Lights" instance=ExtResource("3_lamp")]\nposition = Vector2({room["worldX"]+x+3}, {room["worldY"]+y-4})\nlight_color = '+(color if warm else 'Color(0.62, 0.74, 1, 1)')+'\nlight_energy = 0.85\nlight_scale = 0.8\nshow_body = false\n')
# Both parent containers already exist by this point in the serialized scene.
s=s.replace('[node name="NoteSequence"','\n'.join(blocks)+'\n[node name="NoteSequence"',1)
scene.write_text(s)
print('Installed',len(rows),'room textures and',len(blocks)//2,'window/pool pairs')
