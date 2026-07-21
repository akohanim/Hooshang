#!/usr/bin/env python3
"""Generates levels/level1_office.tscn (+ assets/light_radial.png).

Level 1: The Office — single brick-walled room, played left -> right.
Hooshang wakes against the FAR-LEFT wall in his cramped cubicle. A door stands
a few paces to his right; when he walks up to it, Rumi appears and greets him.
Then the room opens rightward:
  desk hop -> short pillar (jump) -> Rumi grants dash at the tall pillar
  (jump+dash) -> exit door on the far right.

Greybox collision is the TileMapLayer; office pixel-art props are layered on
top purely as decoration (no collision). Grid: 8px tiles, 101 x 26 tiles.

Run from the repo root:  python3 tools/gen_level1.py
Re-running OVERWRITES hand-edits to level1_office.tscn.
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
# Sparse, dim, cold fluorescents. One hangs over the cubicle (left).
COLD = "Color(0.78, 0.92, 0.88, 1)"
lamps = [
    (100, 140, 1.1),  # cubicle lamp (hangs from the low soffit, by the door)
    (392, 92, 0.8),   # short pillar
    (564, 92, 0.8),   # tall pillar
    (760, 112, 0.9),  # exit alcove (right)
]
lamp_nodes = ""
for i, (x, y, e) in enumerate(lamps):
    lamp_nodes += f"""
[node name="Lamp{i}" type="PointLight2D" parent="Lamps"]
position = Vector2({x}, {y})
color = {COLD}
energy = {e}
texture = ExtResource("8_light")
texture_scale = 2.2
"""

# --------------------------------------------------- office-art decor ----
# (file, center_x, center_y, scale, flip_h, dim). Purely visual, no collision;
# the dim flag darkens far/background props for a little depth.
decos = [
    ("office-partitions-1.png", 168, 136, 0.50, False, True),   # cubicle backdrop
    ("desk-with-pc.png",        232, 146, 0.42, False, False),  # Hooshang's desk
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

labels = [
    (52, 118, "Z / SPACE  jump"),
    (744, 100, "EXIT"),
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

scene = f"""[gd_scene load_steps={12 + len(deco_ids)} format=3]

[ext_resource type="TileSet" path="res://assets/tileset.tres" id="1_tileset"]
[ext_resource type="Script" path="res://scripts/level1_office.gd" id="2_script"]
[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="3_player"]
[ext_resource type="PackedScene" path="res://scenes/checkpoint.tscn" id="4_checkpoint"]
[ext_resource type="PackedScene" path="res://scenes/debug_overlay.tscn" id="5_debug"]
[ext_resource type="PackedScene" path="res://scenes/dialogue_box.tscn" id="6_dialogue"]
[ext_resource type="SpriteFrames" path="res://assets/hooshang_frames.tres" id="7_frames"]
[ext_resource type="Texture2D" path="res://assets/light_radial.png" id="8_light"]
{deco_ext}
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
[node name="LampCord" type="ColorRect" parent="."]
offset_left = 99.0
offset_top = 128.0
offset_right = 101.0
offset_bottom = 136.0
color = Color(0.3, 0.3, 0.34, 1)
mouse_filter = 2

[node name="LampBulb" type="ColorRect" parent="."]
offset_left = 96.0
offset_top = 136.0
offset_right = 103.0
offset_bottom = 143.0
color = Color(0.95, 0.95, 0.8, 1)
mouse_filter = 2

[node name="Labels" type="Node2D" parent="."]
{label_nodes}
[node name="DoorFrame" type="ColorRect" parent="."]
offset_left = 109.0
offset_top = 122.0
offset_right = 131.0
offset_bottom = 160.0
color = Color(0.16, 0.11, 0.08, 1)
mouse_filter = 2

[node name="Door" type="ColorRect" parent="."]
offset_left = 112.0
offset_top = 126.0
offset_right = 128.0
offset_bottom = 160.0
color = Color(0.34, 0.22, 0.14, 1)
mouse_filter = 2

[node name="DoorKnob" type="ColorRect" parent="."]
offset_left = 114.0
offset_top = 141.0
offset_right = 116.0
offset_bottom = 144.0
color = Color(0.85, 0.72, 0.35, 1)
mouse_filter = 2

[node name="IntroTrigger" type="Area2D" parent="."]
position = Vector2(120, 140)
collision_layer = 0
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
collision_layer = 0
collision_mask = 2

[node name="Shape" type="CollisionShape2D" parent="DashTrigger"]
shape = SubResource("RectangleShape2D_dash")

[node name="ExitTrigger" type="Area2D" parent="."]
position = Vector2(784, 150)
collision_layer = 0
collision_mask = 2

[node name="Shape" type="CollisionShape2D" parent="ExitTrigger"]
shape = SubResource("RectangleShape2D_exit")

[node name="CanvasModulate" type="CanvasModulate" parent="."]
color = Color(0.09, 0.09, 0.12, 1)

[node name="DialogueBox" parent="." instance=ExtResource("6_dialogue")]

[node name="EndScreen" type="CanvasLayer" parent="."]
layer = 90
visible = false

[node name="Dim" type="ColorRect" parent="EndScreen"]
offset_right = 320.0
offset_bottom = 180.0
color = Color(0, 0, 0, 0.85)

[node name="Text" type="Label" parent="EndScreen"]
offset_left = 60.0
offset_top = 80.0
offset_right = 260.0
offset_bottom = 100.0
horizontal_alignment = 1
theme_override_colors/font_color = Color(1, 0.85, 0.4, 1)
theme_override_font_sizes/font_size = 16
text = "LEVEL COMPLETE"

[node name="DebugOverlay" parent="." instance=ExtResource("5_debug")]
"""

with open(os.path.join(ROOT, "levels", "level1_office.tscn"), "w") as f:
    f.write(scene)
print(f"level1_office.tscn: {len(brick)} brick + {len(gray)} gray tiles, "
      f"{len(lamps)} lamps, {len(decos)} props")
