#!/usr/bin/env python3
"""Generates levels/level1_office.tscn (+ assets/light_radial.png).

Level 1: The Office — five beats, one continuous map. 8px tiles.
Grid: 320 x 73 tiles = 2560 x 584 px. Floor of beats 1-4 sits at row 60
(surface y=480); the exit shaft climbs to ~row 19.

Run from the repo root:  python3 tools/gen_level1.py
Then let Godot (re)import. Hand-edits to level1_office.tscn will be lost if
you re-run this.
"""
import base64
import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

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
solid = set()

def rect(x0, y0, x1, y1):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            solid.add((x, y))

# ==== Beat 1 — Cubicle Intro (x 2..40) =====================================
# Interior is 3 tiles (24px): Hooshang (12px) can stand and barely jump.
rect(0, 50, 1, 66)        # left outer wall
rect(2, 60, 44, 61)       # floor
rect(2, 55, 31, 56)       # low ceiling (interior rows 57..59)
rect(32, 54, 40, 55)      # slightly taller ceiling (interior rows 56..59)
rect(12, 59, 13, 59)      # desk to hop (1 tile — over-desk clearance 16px)
rect(20, 59, 21, 59)      # desk
rect(28, 59, 29, 59)      # desk
rect(36, 58, 37, 59)      # taller partition (needs the 4-tile section)

# ==== Beat 2 — Cubicle Maze (x 41..130) ====================================
# Interior 6 tiles (rows 54..59). Wall grammar:
#   low wall  rows 57..59  -> hop over (24px headroom above its top)
#   hanging   rows 54..57  -> duck under through the 16px slot at the floor
rect(41, 52, 130, 53)     # maze ceiling
rect(45, 60, 99, 61)      # maze floor, left part (hole at 100..102)
rect(103, 60, 112, 61)    # floor between the two basement holes
rect(115, 60, 132, 61)    # floor after exit hole, continues under the doorway
rect(50, 54, 51, 57)      # hanging
rect(56, 57, 57, 59)      # low
rect(62, 54, 63, 57)      # hanging
rect(67, 59, 68, 59)      # desk
rect(72, 57, 73, 59)      # low
rect(78, 54, 79, 57)      # hanging
rect(81, 57, 81, 59)      # step up to the (dead-end) walkway
rect(82, 56, 92, 56)      # overhead walkway — leads nowhere: bait in the dark
rect(91, 54, 92, 55)      # wall sealing the walkway's far end
rect(84, 59, 85, 59)      # desk beneath the walkway
rect(94, 54, 95, 57)      # hanging (above the basement's left wall)
# Basement detour: fall in at 100..102, dead end left, climb out at 113..114.
rect(94, 62, 95, 67)      # basement left wall
rect(94, 66, 118, 67)     # basement floor
rect(117, 62, 118, 67)    # basement right wall
rect(113, 63, 114, 65)    # step block for climbing back out (3 -> 3 jump)
rect(106, 57, 107, 59)    # low
rect(110, 54, 111, 57)    # hanging
rect(120, 57, 121, 59)    # low
rect(126, 54, 127, 57)    # hanging

# ==== Beat 3 — Copy Room (x 131..175) ======================================
# A taller room (12-tile interior): relief after the maze. Rumi lives here.
rect(131, 44, 132, 56)    # entry wall (door slot rows 57..59)
rect(133, 46, 175, 47)    # copy room ceiling
rect(133, 60, 177, 61)    # copy room floor
rect(138, 57, 141, 59)    # copy machine
rect(145, 58, 147, 59)    # low copier / cabinet
rect(152, 59, 154, 59)    # paper stacks
rect(160, 57, 163, 59)    # copy machine
rect(176, 44, 177, 56)    # exit wall (door slot rows 57..59)

# ==== Beat 4 — Manager's Corridor (x 178..283) =============================
# Long flat stretch, interior 6 tiles. Three dash gaps: 6, 8, 9 tiles wide —
# all beyond the ~5-tile max of a plain jump. Pits drop to the kill plane.
rect(178, 52, 283, 53)    # corridor ceiling
rect(178, 60, 195, 61)    # floor
rect(202, 60, 213, 61)    # ... gap 196..201 (6)
rect(222, 60, 237, 61)    # ... gap 214..221 (8)
rect(247, 60, 283, 61)    # ... gap 238..246 (9)

# ==== Beat 5 — Vertical Exit Shaft (x 281..318) ============================
# Jump+dash climb: ledges 4 rows apart (32px) — jump reaches 28px, so every
# hop needs the dash. Refreshes on each ledge.
rect(281, 14, 283, 53)    # shaft left wall (door slot rows 54..59 below)
rect(284, 60, 316, 61)    # shaft floor
rect(317, 12, 318, 66)    # right outer wall
rect(281, 12, 318, 13)    # shaft ceiling
rect(285, 57, 288, 57)    # L1 (24px up — plain jump, the freebie)
rect(293, 53, 296, 53)    # L2
rect(302, 49, 305, 49)    # L3
rect(309, 45, 312, 45)    # L4
rect(302, 41, 305, 41)    # L5
rect(293, 37, 296, 37)    # L6
rect(285, 33, 288, 33)    # L7
rect(294, 28, 298, 28)    # L8 (diagonal dash)
rect(303, 23, 307, 23)    # L9
rect(308, 19, 316, 20)    # exit landing; door at the right end

# TileMapLayer bytes: u16 format, then per cell s16 x, s16 y, u16 src/ax/ay/alt
data = bytearray(struct.pack("<H", 0))
for (x, y) in sorted(solid):
    data += struct.pack("<hhHHHH", x, y, 0, 0, 0, 0)
b64 = base64.b64encode(bytes(data)).decode()

# --------------------------------------------------------------- lamps ----
# (x_px, y_px, energy). Cold + sparse in the maze, denser in the copy room.
COLD = "Color(0.78, 0.92, 0.88, 1)"
lamps = [
    (64, 466, 1.1), (240, 462, 1.0),                       # beat 1
    (464, 442, 1.0), (736, 442, 0.9), (912, 442, 1.0),     # maze — oppressive
    (848, 508, 0.7),                                       # basement gloom
    (1104, 392, 1.2), (1200, 392, 1.2), (1296, 392, 1.2), (1384, 392, 1.1),  # copy room
    (1480, 442, 1.0), (1680, 442, 1.0), (1880, 442, 1.0), (2080, 442, 1.0), (2240, 442, 1.0),  # corridor
    (2320, 400, 1.0), (2480, 336, 1.0), (2360, 272, 1.0), (2480, 200, 1.0), (2500, 140, 1.2),  # shaft
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

labels = [
    (28, 448, "ARROWS / WASD move    Z / SPACE jump"),
    (2490, 132, "EXIT"),
]
label_nodes = ""
for i, (x, y, text) in enumerate(labels):
    label_nodes += f"""
[node name="Hint{i}" type="Label" parent="Labels"]
offset_left = {float(x)}
offset_top = {float(y)}
offset_right = {float(x + 260)}
offset_bottom = {float(y + 12)}
theme_override_colors/font_color = Color(0.8, 0.8, 0.85, 1)
theme_override_font_sizes/font_size = 8
text = "{text}"
"""

checkpoints = [
    ("CP_Maze", 356, 470),         # beat 2 entrance
    ("CP_CopyRoom", 1090, 470),    # immediately before the Rumi trigger
    ("CP_Corridor", 1452, 470),    # beat 4 start
    ("CP_Shaft", 2290, 470),       # beat 5 base
]
cp_nodes = ""
for name, x, y in checkpoints:
    cp_nodes += f"""
[node name="{name}" parent="Checkpoints" instance=ExtResource("4_checkpoint")]
position = Vector2({x}, {y})
"""

scene = f"""[gd_scene load_steps=11 format=3]

[ext_resource type="TileSet" path="res://assets/tileset.tres" id="1_tileset"]
[ext_resource type="Script" path="res://scripts/level1_office.gd" id="2_script"]
[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="3_player"]
[ext_resource type="PackedScene" path="res://scenes/checkpoint.tscn" id="4_checkpoint"]
[ext_resource type="PackedScene" path="res://scenes/debug_overlay.tscn" id="5_debug"]
[ext_resource type="PackedScene" path="res://scenes/dialogue_box.tscn" id="6_dialogue"]
[ext_resource type="SpriteFrames" path="res://assets/hooshang_frames.tres" id="7_frames"]
[ext_resource type="Texture2D" path="res://assets/light_radial.png" id="8_light"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_rumi"]
size = Vector2(48, 80)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_exit"]
size = Vector2(32, 32)

[node name="Level1Office" type="Node2D"]
script = ExtResource("2_script")
camera_limits = Rect2i(0, 0, 2552, 584)
kill_y = 552.0

[node name="Terrain" type="TileMapLayer" parent="."]
tile_map_data = PackedByteArray("{b64}")
tile_set = ExtResource("1_tileset")

[node name="SpawnPoint" type="Marker2D" parent="."]
position = Vector2(48, 474)

[node name="Player" parent="." instance=ExtResource("3_player")]
position = Vector2(48, 474)
has_dash = false

[node name="Checkpoints" type="Node2D" parent="."]
{cp_nodes}
[node name="Lamps" type="Node2D" parent="."]
{lamp_nodes}
[node name="Labels" type="Node2D" parent="."]
{label_nodes}
[node name="Rumi" type="AnimatedSprite2D" parent="."]
modulate = Color(1, 0.85, 0.4, 0)
position = Vector2(1264, 474)
scale = Vector2(0.5, 0.5)
sprite_frames = ExtResource("7_frames")
animation = &"idle"
autoplay = "idle"
flip_h = true
offset = Vector2(0, -20)

[node name="RumiLight" type="PointLight2D" parent="."]
position = Vector2(1264, 455)
color = Color(1, 0.82, 0.45, 1)
energy = 0.0
texture = ExtResource("8_light")
texture_scale = 2.8

[node name="RumiTrigger" type="Area2D" parent="."]
position = Vector2(1224, 440)
collision_layer = 0
collision_mask = 2

[node name="Shape" type="CollisionShape2D" parent="RumiTrigger"]
shape = SubResource("RectangleShape2D_rumi")

[node name="ExitTrigger" type="Area2D" parent="."]
position = Vector2(2520, 136)
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
print(f"level1_office.tscn: {len(solid)} tiles, {len(lamps)} lamps")
