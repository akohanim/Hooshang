#!/usr/bin/env python3
"""Generates scenes/levels/act1_office/Level2.tscn.

Level 2 — an ascending three-jump gauntlet (dash already granted in Level 1),
from the design sketch. Left -> right, each jump harder:
  Jump 1  — a max-height plain jump (no dash).      gap 3t,  rise 3t
  Jump 2  — jump + dash, generous landing.          gap 6t,  rise 3t
  Jump 3  — jump + dash at the ABSOLUTE limit.       gap 11t, rise 2t
Measured max jump+dash reach is 87px at a 3-tile rise but 90px at a 2-tile rise
(less height to buy = more horizontal). So jump 3 rises only 2 tiles and spans
11 tiles / 88px — ~2px inside the 90px ceiling, a near-frame-perfect apex dash.
Miss any gap and you fall into the pit (kill plane) and respawn at the start.
No checkpoints.

The room has a thin colliding brick shell (ceiling + walls) and grey platforms;
the interior is hollow, revealing the OfficeBackdrop prefab (moon-window,
drifting papers) behind it — same treatment as Level 1.

Run from repo root:  python3 tools/gen_level2.py
Re-running OVERWRITES hand-edits to Level2.tscn.
"""
import base64
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

W_TILES, H_TILES = 72, 34             # 576 x 272 px
brick, gray = set(), set()

# Backdrop placement (OfficeBackdrop's moon-window + paper drift), in the open
# wall space above the platforms, roughly centered over the jump sequence.
BACKDROP_MOON_X, BACKDROP_MOON_Y = 280, 90

def rect(dst, x0, y0, x1, y1):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            dst.add((x, y))

# --- colliding shell: ceiling + side walls (no floor — the bottom is a pit) ---
rect(brick, 0, 0, W_TILES - 1, 2)
rect(brick, 0, 0, 1, H_TILES - 1)
rect(brick, W_TILES - 2, 0, W_TILES - 1, H_TILES - 1)

# --- tile-aligned platforms (grey), ascending, HALF the previous width. -------
# P3 is NOT here — it needs a sub-tile x to sit exactly at the jump+dash limit,
# so it's a separately-positioned TileMapLayer below (P3_X/P3_SURF).
PLATFORMS = [
    (3, 12, 28),    # P0 start
    (16, 23, 25),   # P1  <- Jump 1: max-height plain jump   (gap 3t)
    (30, 39, 22),   # P2  <- Jump 2: jump + dash, generous    (gap 6t)
]
for (x0, x1, top) in PLATFORMS:
    rect(gray, x0, top, x1, top + 1)

# P3 — the perfect jump. P2's right edge is x=320; the max landable jump+dash gap
# at a 2-tile rise is 95px (measured), so P3 sits 94px out (1px inside the limit,
# a frame-perfect landing) and 2 tiles up. Pixel-positioned, 13 tiles wide.
P3_X = 320 + 94        # 414 — left edge, off the tile grid on purpose
P3_SURF = 160          # 2 tiles above P2's surface (176)
P3_W = 13

def tilemap_bytes(cells):
    data = bytearray(struct.pack("<H", 0))
    for (x, y, ax) in cells:
        data += struct.pack("<hhHHHH", x, y, 0, ax, 0, 0)
    return base64.b64encode(bytes(data)).decode()

# Foreground (colliding): red-brick shell (atlas 1) + grey platforms (atlas 0).
fg = [(x, y, 1) for (x, y) in sorted(brick)] + [(x, y, 0) for (x, y) in sorted(gray)]
fg_b64 = tilemap_bytes(sorted(set((x, y, a) for (x, y, a) in fg)))

# P3's own (local) tiles — 13 wide x 2 tall grey slab, placed at P3_X/P3_SURF.
p3_b64 = tilemap_bytes([(x, y, 0) for x in range(P3_W) for y in range(2)])

# --- lamps over the platforms (LampFixture prefab instances) ------------------
lamps = [
    (64, 200, 1.0, False, 0.0),
    (156, 176, 1.0, False, 0.0),
    (276, 152, 1.0, False, 0.0),
    (464, 136, 1.1, False, 0.0),
]
lamp_nodes = ""
for i, (x, y, e, body, cl) in enumerate(lamps):
    lamp_nodes += f"""
[node name="Lamp{i}" parent="Lamps" instance=ExtResource("6_lamp")]
position = Vector2({x}, {y})
light_energy = {e}
show_body = {str(body).lower()}
cable_length = {cl}
"""

labels = [
    (36, 208, "JUMP"),
    (152, 168, "JUMP + DASH"),
    (312, 132, "JUMP + DASH  (perfect!)"),
]
label_nodes = ""
for i, (x, y, text) in enumerate(labels):
    label_nodes += f"""
[node name="Hint{i}" type="Label" parent="Labels"]
offset_left = {float(x)}
offset_top = {float(y)}
offset_right = {float(x + 200)}
offset_bottom = {float(y + 10)}
theme_override_colors/font_color = Color(0.85, 0.85, 0.9, 1)
theme_override_font_sizes/font_size = 8
text = "{text}"
"""

spawn_x, spawn_y = 52, 218        # on P0 (top_row 28 -> surface y=224)
exit_x, exit_y = 480, 154         # on P3 (top_row 20 -> surface y=160), near right end

scene = f"""[gd_scene load_steps=10 format=3]

[ext_resource type="TileSet" path="res://assets/tileset.tres" id="1_tileset"]
[ext_resource type="Script" path="res://scripts/level_base.gd" id="2_script"]
[ext_resource type="PackedScene" path="res://scenes/characters/hooshang/Hooshang.tscn" id="3_player"]
[ext_resource type="PackedScene" path="res://scenes/ui/DebugOverlay.tscn" id="4_debug"]
[ext_resource type="Texture2D" path="res://assets/light_radial.png" id="5_light"]
[ext_resource type="PackedScene" path="res://scenes/props/lighting/LampFixture.tscn" id="6_lamp"]
[ext_resource type="PackedScene" path="res://scenes/props/ExitSign.tscn" id="7_sign"]
[ext_resource type="PackedScene" path="res://scenes/props/backdrop/OfficeBackdrop.tscn" id="8_backdrop"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_exit"]
size = Vector2(20, 24)

[node name="Level2" type="Node2D"]
script = ExtResource("2_script")
camera_limits = Rect2i(0, 0, {W_TILES * 8}, {H_TILES * 8})
kill_y = {(H_TILES - 1) * 8}.0

[node name="OfficeBackdrop" parent="." instance=ExtResource("8_backdrop")]

[node name="MoonWindow" parent="OfficeBackdrop/Midground" index="0"]
position = Vector2({BACKDROP_MOON_X}, {BACKDROP_MOON_Y})

[node name="Papers" parent="OfficeBackdrop/Atmosphere" index="0"]
position = Vector2({BACKDROP_MOON_X}, {BACKDROP_MOON_Y + 10})

[node name="Papers2" parent="OfficeBackdrop/Atmosphere" index="1"]
position = Vector2({BACKDROP_MOON_X - 40}, {BACKDROP_MOON_Y + 40})

[node name="Terrain" type="TileMapLayer" parent="."]
tile_map_data = PackedByteArray("{fg_b64}")
tile_set = ExtResource("1_tileset")

[node name="Platform3" type="TileMapLayer" parent="."]
position = Vector2({P3_X}, {P3_SURF})
tile_map_data = PackedByteArray("{p3_b64}")
tile_set = ExtResource("1_tileset")

[node name="SpawnPoint" type="Marker2D" parent="."]
position = Vector2({spawn_x}, {spawn_y})

[node name="Player" parent="." instance=ExtResource("3_player")]
position = Vector2({spawn_x}, {spawn_y})
has_dash = true

[node name="Checkpoints" type="Node2D" parent="."]

[node name="Lamps" type="Node2D" parent="."]
{lamp_nodes}
[node name="Labels" type="Node2D" parent="."]
{label_nodes}
[node name="ExitSign" parent="." instance=ExtResource("7_sign")]
position = Vector2({exit_x + 8}, {exit_y - 22})

[node name="ExitTrigger" type="Area2D" parent="." groups=["exit"]]
position = Vector2({exit_x}, {exit_y})
collision_layer = 8
collision_mask = 2

[node name="Shape" type="CollisionShape2D" parent="ExitTrigger"]
shape = SubResource("RectangleShape2D_exit")

[node name="CanvasModulate" type="CanvasModulate" parent="."]
color = Color(0.11, 0.1, 0.13, 1)

[node name="DebugOverlay" parent="." instance=ExtResource("4_debug")]
"""

out = os.path.join(ROOT, "scenes", "levels", "act1_office", "Level2.tscn")
with open(out, "w") as f:
    f.write(scene)

print(f"Level2.tscn: {len(brick)} brick shell + {len(gray)} gray platform tiles, hollow interior")
for i in range(len(PLATFORMS) - 1):
    a, b = PLATFORMS[i], PLATFORMS[i + 1]
    gap = b[0] * 8 - (a[1] + 1) * 8
    rise = (a[2] - b[2]) * 8
    print(f"  Jump {i+1}: gap {gap}px ({gap//8}t), rise {rise}px ({rise//8}t)")
p2 = PLATFORMS[-1]
print(f"  Jump 3: gap {P3_X - (p2[1]+1)*8}px, rise {p2[2]*8 - P3_SURF}px  (sub-tile, at the limit)")
