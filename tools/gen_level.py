#!/usr/bin/env python3
"""Generates assets/tiles.png and scenes/levels/TestLevel.tscn for Hooshang.

The level is a linear gauntlet; each section isolates one movement mechanic.
Tile grid: 8px tiles. Level bounds: 302 x 46 tiles = 2416 x 368 px.
"""
import base64
import os
import struct
import zlib

ROOT = "/Users/ari/Hooshang_claude"
TILE = 8

# ---------------------------------------------------------------- tiles.png
def png_chunk(tag, data):
    c = tag + data
    return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

def write_png(path, w, h, px):  # px[y][x] = (r,g,b,a)
    raw = b""
    for y in range(h):
        raw += b"\x00" + b"".join(bytes(p) for p in px[y])
    data = (b"\x89PNG\r\n\x1a\n"
            + png_chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + png_chunk(b"IDAT", zlib.compress(raw))
            + png_chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(data)

def make_tile(base, light, dark):
    t = [[base] * 8 for _ in range(8)]
    for i in range(8):
        t[0][i] = light          # lit top edge
        t[7][i] = dark           # dark bottom edge
        t[i][0] = dark
        t[i][7] = dark
    return t

def make_brick():
    # NYC / Super-Mario style red brick: two 3px courses of running-bond
    # bricks separated by dark mortar. The head joints (vertical mortar) are
    # offset half a brick between the two courses, so tiling gives the classic
    # staggered wall. Each brick gets a lit top pixel and a shaded bottom pixel.
    BRICK = (168, 62, 47, 255)   # red brick face
    HI    = (201, 99, 80, 255)   # sunlit top of each brick
    LO    = (138, 47, 35, 255)   # shaded bottom of each brick
    MORTAR = (58, 43, 41, 255)   # dark mortar joints
    t = [[BRICK] * 8 for _ in range(8)]
    for y in range(8):
        for x in range(8):
            if y == 3 or y == 7:                 # horizontal bed joints
                t[y][x] = MORTAR
            elif y < 3:                          # top course
                if x == 0:                       # head joint at the left edge
                    t[y][x] = MORTAR
                else:
                    t[y][x] = HI if y == 0 else LO if y == 2 else BRICK
            else:                                # bottom course (offset joint)
                if x == 4:                       # head joint in the middle
                    t[y][x] = MORTAR
                else:
                    t[y][x] = HI if y == 4 else LO if y == 6 else BRICK
    return t

# tile0 = neutral grey — used for OBSTACLES (pillars, desk collision) so they
# stay visually distinct from the walls. tile1 = the building's red brick,
# used for the room shell (walls/ceiling/floor).
tile0 = make_tile((140, 145, 155, 255), (190, 195, 205, 255), (95, 100, 110, 255))
tile1 = make_brick()
pixels = [tile0[y] + tile1[y] for y in range(8)]
write_png(os.path.join(ROOT, "assets", "tiles.png"), 16, 8, pixels)

# ------------------------------------------------------------ solid tiles
solid = set()

def rect(x0, y0, x1, y1):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            solid.add((x, y))

# Section 1 — flat runway (floor top at row 40, y=320)
rect(0, 20, 1, 45)        # left boundary wall
rect(2, 40, 55, 45)       # runway floor

# Section 2 — staircase of gaps, widths 2 / 3 / 4 / 5 tiles
rect(58, 40, 67, 45)
rect(71, 40, 80, 45)
rect(85, 40, 94, 45)
rect(100, 40, 110, 45)

# Section 3 — coyote ledges: raised blocks over a safety floor
rect(111, 44, 190, 45)    # safety/lower floor (continues under section 4)
rect(113, 41, 120, 43)
rect(123, 41, 130, 43)
rect(133, 41, 140, 43)

# Section 4 — low-ceiling corridor (interior 24px tall) with 8px bumps
rect(150, 39, 180, 40)    # ceiling
rect(160, 43, 160, 43)    # bump
rect(170, 43, 170, 43)    # bump

# Section 5 — dash gap (8 tiles) then diagonal-dash climb (6 across, 5 up)
rect(199, 44, 208, 45)
rect(215, 39, 231, 45)

# Section 6 — wall shaft (interior 5 tiles wide, entrance under left wall)
rect(223, 6, 224, 34)     # left wall (gap below = walk-in entrance)
rect(230, 12, 231, 38)    # right wall (its top is the exit ledge)
rect(232, 12, 252, 13)    # upper platform after the shaft

# Section 7 — spike pit with mid pillar
rect(253, 16, 262, 17)    # pit floor (spikes sit on top)
rect(257, 12, 258, 13)    # safe mid pillar
rect(263, 12, 275, 13)    # landing platform

# Section 8 — combo room: jump+dash gap, then a short wall shaft to the top
rect(285, 12, 292, 13)    # landing after the 9-tile gap
rect(293, 14, 301, 15)    # combo shaft floor
rect(293, 4, 294, 9)      # combo shaft left wall (exit over its top)
rect(284, 2, 294, 3)      # final END platform
rect(300, 0, 301, 45)     # right boundary wall

# TileMapLayer byte format: u16 format version, then per cell:
# s16 x, s16 y, u16 source_id, u16 atlas_x, u16 atlas_y, u16 alternative.
data = bytearray(struct.pack("<H", 0))
for (x, y) in sorted(solid):
    data += struct.pack("<hhHHHH", x, y, 0, 0, 0, 0)
b64 = base64.b64encode(bytes(data)).decode()

# ------------------------------------------------------------- scene text
labels = [
    (16, 244, "ARROWS/WASD move   Z/SPACE jump   X/SHIFT dash   R respawn   F3 debug"),
    (20, 292, "1  RUN - top speed, accel, turnaround"),
    (460, 292, "2  JUMP - gaps: 2, 3, 4, 5 tiles"),
    (900, 302, "3  COYOTE - run off, jump late"),
    (1140, 332, "4  LOW CEILING - tap-jump short hops"),
    (1450, 332, "5  DASH - flat gap needs a dash, then an up-forward dash"),
    (1710, 288, "6  WALL SHAFT - slide + wall-jump up"),
    (1868, 72, "7  SPIKES - checkpoint + fast respawn"),
    (2100, 72, "8  COMBO - jump, dash, wall-jump"),
    (2284, 4, "END"),
]
label_nodes = ""
for i, (x, y, text) in enumerate(labels):
    label_nodes += f"""
[node name="L{i}" type="Label" parent="Labels"]
offset_left = {float(x)}
offset_top = {float(y)}
offset_right = {float(x + 300)}
offset_bottom = {float(y + 12)}
theme_override_colors/font_color = Color(0.85, 0.85, 0.9, 1)
theme_override_font_sizes/font_size = 8
text = "{text}"
"""

scene = f"""[gd_scene load_steps=7 format=3]

[ext_resource type="TileSet" path="res://assets/tileset.tres" id="1_tileset"]
[ext_resource type="Script" path="res://scripts/level_base.gd" id="2_level"]
[ext_resource type="PackedScene" path="res://scenes/characters/hooshang/Hooshang.tscn" id="3_player"]
[ext_resource type="PackedScene" path="res://scenes/props/Checkpoint.tscn" id="4_checkpoint"]
[ext_resource type="PackedScene" path="res://scenes/props/hazards/Hazard.tscn" id="5_hazard"]
[ext_resource type="PackedScene" path="res://scenes/ui/DebugOverlay.tscn" id="6_debug"]

[node name="TestLevel" type="Node2D"]
script = ExtResource("2_level")
camera_limits = Rect2i(0, 0, 2416, 368)
kill_y = 400.0

[node name="Terrain" type="TileMapLayer" parent="."]
tile_map_data = PackedByteArray("{b64}")
tile_set = ExtResource("1_tileset")

[node name="SpawnPoint" type="Marker2D" parent="."]
position = Vector2(32, 312)

[node name="Player" parent="." instance=ExtResource("3_player")]
position = Vector2(32, 312)

[node name="Checkpoints" type="Node2D" parent="."]

[node name="CP1_BeforeDash" parent="Checkpoints" instance=ExtResource("4_checkpoint")]
position = Vector2(1492, 342)

[node name="CP2_BeforeSpikes" parent="Checkpoints" instance=ExtResource("4_checkpoint")]
position = Vector2(1892, 86)

[node name="CP3_End" parent="Checkpoints" instance=ExtResource("4_checkpoint")]
position = Vector2(2320, 6)

[node name="Hazards" type="Node2D" parent="."]

[node name="SpikesA" parent="Hazards" instance=ExtResource("5_hazard")]
position = Vector2(2040, 124)
size = Vector2(32, 8)

[node name="SpikesB" parent="Hazards" instance=ExtResource("5_hazard")]
position = Vector2(2088, 124)
size = Vector2(32, 8)

[node name="Labels" type="Node2D" parent="."]
{label_nodes}
[node name="CanvasModulate" type="CanvasModulate" parent="."]
color = Color(1, 1, 1, 1)

[node name="DebugOverlay" parent="." instance=ExtResource("6_debug")]
"""

with open(os.path.join(ROOT, "scenes", "levels", "TestLevel.tscn"), "w") as f:
    f.write(scene)

print(f"tiles: {len(solid)} cells, scene + png written")
