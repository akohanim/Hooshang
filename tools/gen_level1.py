#!/usr/bin/env python3
"""Generates scenes/levels/act1_office/Level1Office.tscn (+ assets/light_radial.png).

Level 1: The Office — single brick-walled room, played left -> right.
Hooshang wakes against the FAR-LEFT wall in his cramped cubicle. A door stands
a few paces to his right; when he walks up to it, Rumi appears and greets him.
Then the room opens rightward:
  desk hop -> short pillar (jump) -> Rumi grants dash at the tall pillar
  (jump+dash) -> exit door on the far right.

Greybox collision is the TileMapLayer; office pixel-art props are layered on
top purely as decoration (no collision). Grid: 8px tiles, 101 x 26 tiles.

Run from the repo root:  python3 tools/gen_level1.py
Re-running OVERWRITES hand-edits to Level1Office.tscn.
"""
import base64
import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = "res://assets/office-pixel-art/free-office-pixel-art"

# ------------------------------------------------------- light texture ----
def png_chunk(tag, data):
    c = tag + data
    return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

def write_light_png(path, size=128):
    rows = []
    r_max = size / 2.0
    for y in range(size):
        row = []
        for x in range(size):
            d = math.hypot(x - r_max + 0.5, y - r_max + 0.5) / r_max
            a = max(0.0, 1.0 - d)
            v = int(255 * a * a)  # quadratic falloff = soft-edged pool
            row += [255, 255, 255, v]
        rows.append(row)
    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(raw)) + png_chunk(b"IEND", b""))

write_light_png(os.path.join(ROOT, "assets", "light_radial.png"))

# ------------------------------------------------------------ geometry ----
# Two tile looks: brick frame uses atlas tile (1,0), office furniture (0,0).
brick = set()
gray = set()

def rect(dst, x0, y0, x1, y1):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            dst.add((x, y))

# Brick shell around the whole room ("surrounded by brick on all sides").
rect(brick, 0, 0, 100, 5)      # ceiling slab
rect(brick, 0, 20, 100, 25)    # floor slab
rect(brick, 0, 6, 3, 19)       # left wall
rect(brick, 97, 6, 100, 19)    # right wall
# Exit door alcove carved into the RIGHT wall at floor level (level end).
for x in range(97, 99):
    for y in range(15, 20):
        brick.discard((x, y))

# Cramped cubicle on the LEFT: a low brick soffit boxes in the wake-up area so
# it feels claustrophobic, then opens to full height as he walks to the door.
rect(brick, 4, 6, 40, 14)      # lowered cubicle ceiling (soffit bulkhead)
rect(brick, 5, 15, 13, 15)     # extra-low nook over the wake-up spot (left)

# Furniture footprint (art is layered on top; collision lives here).
rect(gray, 28, 18, 30, 19)     # desk (hop over = first jump, moving right)

# Short pillar — plain jump clears it (3 tiles = 24px, jump reaches ~28px).
rect(gray, 48, 17, 49, 19)

# Tall pillar — 6 tiles (48px): impossible without the dash Rumi grants here
# (jump 28px + upward dash ~39px clears it with room to spare).
rect(gray, 70, 14, 71, 19)

# TileMapLayer bytes: u16 format, then per cell s16 x, s16 y, u16 src/ax/ay/alt
data = bytearray(struct.pack("<H", 0))
for (x, y) in sorted(brick | gray):
    ax = 1 if (x, y) in brick else 0
    data += struct.pack("<hhHHHH", x, y, 0, ax, 0, 0)
b64 = base64.b64encode(bytes(data)).decode()

# --------------------------------------------------------------- lamps ----
# Sparse, dim, cold fluorescents, each an instance of the LampFixture prefab.
# (x, y, energy, show_body, cable_length). Every lamp shows its cable+bulb so
# it reads as a real fixture; the cable reaches up to the ceiling slab (bottom
# edge at y=48 in the open room, y=128 under the low cubicle soffit).
lamps = [
    (100, 140, 1.1, True, 12.0),  # cubicle lamp (hangs from the low soffit)
    (392, 92, 0.9, True, 44.0),   # short pillar
    (564, 92, 0.9, True, 44.0),   # tall pillar
    (760, 112, 0.95, True, 64.0), # exit alcove (right)
]
lamp_nodes = ""
for i, (x, y, e, body, cl) in enumerate(lamps):
    lamp_nodes += f"""
[node name="Lamp{i}" parent="Lamps" instance=ExtResource("LAMP_FIXTURE")]
position = Vector2({x}, {y})
light_energy = {e}
show_body = {str(body).lower()}
cable_length = {cl}
"""

# --------------------------------------------------- office-art decor ----
# (file, center_x, center_y, scale, flip_h, dim). Purely visual, no collision;
# the dim flag darkens far/background props for a little depth.
decos = [
    # Opening cubicle where Hooshang wakes (far left, by the spawn).
    ("Chair.png",               52,  153, 0.55, False, False),  # his chair
    ("desk-with-pc.png",        76,  146, 0.42, True,  False),  # his desk
    # The rest of the office, left -> right.
    ("office-partitions-1.png", 168, 136, 0.50, False, True),   # cubicle backdrop
    ("desk-with-pc.png",        232, 146, 0.42, False, False),  # a passing desk
    ("Chair.png",               250, 153, 0.55, True,  False),
    ("worker1.png",             316, 150, 0.40, False, True),   # neighbour cubicle
    ("cabinet.png",             356, 150, 0.42, False, False),
    ("water-cooler.png",        430, 147, 0.70, False, False),
    ("printer.png",             472, 151, 0.45, False, False),
    ("plant.png",               520, 151, 0.55, False, False),
    ("worker2.png",             630, 150, 0.40, True,  True),   # far cubicle
    ("coffee-maker.png",        680, 146, 0.40, False, False),
    ("Trash.png",               740, 154, 0.75, False, False),
]
# Assign ext_resource ids to the unique textures used.
deco_ids = {}
deco_ext = ""
next_id = 9
for (f, *_rest) in decos:
    if f not in deco_ids:
        deco_ids[f] = f"{next_id}_{f.split('.')[0].replace('-', '_').lower()}"
        deco_ext += f'[ext_resource type="Texture2D" path="{ART}/{f}" id="{deco_ids[f]}"]\n'
        next_id += 1
deco_nodes = ""
for i, (f, x, y, s, flip, dim) in enumerate(decos):
    mod = "\nmodulate = Color(0.7, 0.7, 0.8, 1)" if dim else ""
    deco_nodes += f"""
[node name="Deco{i}_{f.split('.')[0].replace('-', '_')}" type="Sprite2D" parent="Decor"]
position = Vector2({x}, {y})
scale = Vector2({s}, {s})
flip_h = {str(flip).lower()}
texture = ExtResource("{deco_ids[f]}"){mod}
"""

# Prefab ext ids follow the deco ids to avoid collisions.
lamp_id = f"{next_id}_lampfixture"
door_id = f"{next_id + 1}_door"
sign_id = f"{next_id + 2}_exitsign"
lamp_ext = (
    f'[ext_resource type="PackedScene" path="res://scenes/props/lighting/LampFixture.tscn" id="{lamp_id}"]\n'
    f'[ext_resource type="PackedScene" path="res://scenes/props/Door.tscn" id="{door_id}"]\n'
    f'[ext_resource type="PackedScene" path="res://scenes/props/ExitSign.tscn" id="{sign_id}"]\n'
)
lamp_nodes = lamp_nodes.replace("LAMP_FIXTURE", lamp_id)

labels = [
    (52, 118, "Z / SPACE  jump"),
]
label_nodes = ""
for i, (x, y, text) in enumerate(labels):
    label_nodes += f"""
[node name="Hint{i}" type="Label" parent="Labels"]
offset_left = {float(x)}
offset_top = {float(y)}
offset_right = {float(x + 200)}
offset_bottom = {float(y + 12)}
theme_override_colors/font_color = Color(0.8, 0.8, 0.85, 1)
theme_override_font_sizes/font_size = 8
text = "{text}"
"""

scene = f"""[gd_scene load_steps={14 + len(deco_ids)} format=3]

[ext_resource type="TileSet" path="res://assets/tileset.tres" id="1_tileset"]
[ext_resource type="Script" path="res://scenes/levels/act1_office/level1_office.gd" id="2_script"]
[ext_resource type="PackedScene" path="res://scenes/characters/hooshang/Hooshang.tscn" id="3_player"]
[ext_resource type="PackedScene" path="res://scenes/props/Checkpoint.tscn" id="4_checkpoint"]
[ext_resource type="PackedScene" path="res://scenes/ui/DebugOverlay.tscn" id="5_debug"]
[ext_resource type="SpriteFrames" path="res://assets/rumi_frames.tres" id="7_frames"]
[ext_resource type="Texture2D" path="res://assets/light_radial.png" id="8_light"]
[ext_resource type="PackedScene" path="res://scenes/props/backdrop/OfficeBackdrop.tscn" id="100_backdrop"]
{deco_ext}{lamp_ext}
[sub_resource type="RectangleShape2D" id="RectangleShape2D_intro"]
size = Vector2(24, 40)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_dash"]
size = Vector2(48, 40)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_exit"]
size = Vector2(16, 40)

[node name="Level1Office" type="Node2D"]
script = ExtResource("2_script")
camera_limits = Rect2i(0, 0, 808, 208)
kill_y = 300.0

[node name="OfficeBackdrop" parent="." instance=ExtResource("100_backdrop")]

[node name="Terrain" type="TileMapLayer" parent="."]
tile_map_data = PackedByteArray("{b64}")
tile_set = ExtResource("1_tileset")

[node name="Decor" type="Node2D" parent="."]
{deco_nodes}
[node name="SpawnPoint" type="Marker2D" parent="."]
position = Vector2(48, 154)

[node name="Player" parent="." instance=ExtResource("3_player")]
position = Vector2(48, 154)
has_dash = false

[node name="Checkpoints" type="Node2D" parent="."]

[node name="Lamps" type="Node2D" parent="."]
{lamp_nodes}
[node name="Labels" type="Node2D" parent="."]
{label_nodes}
[node name="Door" parent="." instance=ExtResource("{door_id}")]
position = Vector2(109, 122)

[node name="IntroTrigger" type="Area2D" parent="."]
position = Vector2(120, 140)
collision_layer = 8
collision_mask = 2

[node name="Shape" type="CollisionShape2D" parent="IntroTrigger"]
shape = SubResource("RectangleShape2D_intro")

[node name="Rumi" type="AnimatedSprite2D" parent="."]
modulate = Color(1, 0.85, 0.4, 0)
position = Vector2(132, 154)
scale = Vector2(0.5, 0.5)
sprite_frames = ExtResource("7_frames")
animation = &"idle"
autoplay = "idle"
flip_h = true
offset = Vector2(0, -20)

[node name="RumiLight" type="PointLight2D" parent="."]
position = Vector2(132, 135)
color = Color(1, 0.82, 0.45, 1)
energy = 0.0
texture = ExtResource("8_light")
texture_scale = 2.8

[node name="DashTrigger" type="Area2D" parent="."]
position = Vector2(520, 140)
collision_layer = 8
collision_mask = 2

[node name="Shape" type="CollisionShape2D" parent="DashTrigger"]
shape = SubResource("RectangleShape2D_dash")

[node name="ExitSign" parent="." instance=ExtResource("{sign_id}")]
position = Vector2(780, 106)

[node name="ExitTrigger" type="Area2D" parent="." groups=["exit"]]
position = Vector2(784, 150)
collision_layer = 8
collision_mask = 2

[node name="Shape" type="CollisionShape2D" parent="ExitTrigger"]
shape = SubResource("RectangleShape2D_exit")

[node name="CanvasModulate" type="CanvasModulate" parent="."]
color = Color(0.09, 0.09, 0.12, 1)

[node name="DebugOverlay" parent="." instance=ExtResource("5_debug")]
"""

out_path = os.path.join(ROOT, "scenes", "levels", "act1_office", "Level1Office.tscn")
with open(out_path, "w") as f:
    f.write(scene)
print(f"Level1Office.tscn: {len(brick)} brick + {len(gray)} gray tiles, "
      f"{len(lamps)} lamps, {len(decos)} props")
