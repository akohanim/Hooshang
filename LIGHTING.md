# Lighting — a working guide

How to light rooms in this project by hand, and the handful of rules that stop
it going wrong. Everything here is 2D lighting: `CanvasModulate` for darkness,
`PointLight2D` (wrapped in `LampFixture.tscn`) for light.

---

## The two knobs

**1. `CanvasModulate` — the master darkness.** One node in `ldtk/Act1World.tscn`,
currently `Color(0.05, 0.05, 0.065)`. It multiplies *everything* in the world, so
at 0.05 the rooms are nearly black and lights are what you see. Raise it to make
the whole Act lighter; it is the wrong tool for lighting one room.

**2. `LampFixture.tscn` — every actual light.** Instanced under the `Lights` node
in `Act1World.tscn`. Never add a bare `PointLight2D`: the fixture wraps one with
per-instance settings and joins the `lights` group, which future systems (the
manager's light-sweep) will use to find every lamp at once.

### LampFixture settings

| Export | What it does |
| --- | --- |
| `light_color` | Colour of the pool. Default is cold fluorescent; warm office lamps recolour it |
| `light_energy` | Brightness. Fill lights use ~2.0, feature lights 1.3–1.9 |
| `light_scale` | **Size of the pool** — see the radius formula below |
| `show_body` | `true` draws the physical cable + bulb; `false` is an invisible source (all fill lights use `false`) |
| `cable_length` | How far the bulb hangs below its anchor, in px |
| `flickers` / `flicker_amount` / `flicker_speed` | Fluorescent sputter. Off by default — the cubicle bulb is the only one using it |

---

## The one number that matters: radius

`assets/light_radial.png` is **128 px**, so its untouched radius is 64 px:

```
radius in pixels = 64 × light_scale
```

| `light_scale` | Radius | Typical use |
| --- | --- | --- |
| 0.75 | 48 px | A tight pool — lighting a spawn point or a single feature |
| 1.05 | 67 px | Small fill in a corner |
| 1.3 | 83 px | A puzzle / prop light |
| 2.0 | 128 px | Normal fill |
| 3.0 | 192 px | Wide fill — **wider than half a room** |

Keep this in your head, because it is what causes the one real trap.

---

## The trap: rooms are neighbours, and light crosses the seam

Every room of the Act is loaded at once, side by side, in one big world. A light
does **not** stop at a room's edge. A `light_scale = 3.0` fill has a 192 px reach,
which is more than half a 320 px room — so a light near a room's edge spills into
the room next door.

This has already broken the game once: two normal fills placed in room 6 lit up
room 5's cave through the shared seam, taking it from 6.6 to 36.1 brightness and
undoing the darkness that room is designed around.

**The rule.** If the room next door must stay dark:

```
light_x − radius  ≥  room_left_edge
light_x + radius  ≤  room_right_edge
```

If that forces the light too small to cover the room, use **several smaller
lights** rather than one big one. That is exactly why room 6 has four.

### Room positions (world X)

Lights are positioned in **world coordinates**, not per room, so you need these:

| Room | LDtk name | World X | Notes |
| --- | --- | --- | --- |
| 1 | `Level_1_Office` | 0 – 320 | Dim on purpose — the cubicle is a prison |
| 2 | `Level_1` | 320 – 640 | |
| 3 | `Level_2` | 608 – 928 | |
| 4 | `Level_3` | 928 – 1248 | |
| 5 | `Level_4` | 1248 – 1568 | **Cave** — lit at the musical tiles, dark after |
| 6 | `Level_5` | 1568 – 1888 | |

Floor level is around **y = 336**; fill lights sit at **y = 250** (mid-room).

> These shift whenever you add or move a room in LDtk. Re-check them before
> placing anything — see *When you add a room* below.

---

## Adding a light fixture

1. Open `ldtk/Act1World.tscn`.
2. Select the **`Lights`** node.
3. Drag `scenes/props/lighting/LampFixture.tscn` from the FileSystem dock onto
   it (or **Ctrl/Cmd + Shift + A** → Instance Child Scene).
4. Set **Transform → Position** to a world coordinate inside the target room.
5. Set the exports in the Inspector. For a normal fill: `light_energy 2.0`,
   `light_scale 2.0`, `show_body false`.
6. Check the radius against the seam rule above.
7. Run it — pick the room straight from the debug picker (F5), no need to play
   up to it.

**Name it for the room it serves.** The convention in the scene is
`FillRoomNa` / `FillRoomNb` for general fill, and a descriptive name for a
feature light (`PuzzleLightRoom5`, `SpawnLightRoom6`, `CubicleBulb`). When rooms
shift, these names are how you tell what is now in the wrong place.

### Recipes

```
Normal room fill        energy 2.0   scale 2.0   show_body false
Wide fill (mid-room)    energy 2.0   scale 3.0   show_body false   ← watch seams
Feature / puzzle light  energy 1.9   scale 1.3   show_body false
Spawn point             energy 1.7   scale 0.75  show_body false
Visible ceiling lamp    energy 1.15  scale 2.4   show_body true    + flickers
```

---

## Adding the full-moon window

`scenes/props/backdrop/MoonWindow.tscn` is **art only** — a navy sky patch, the
moon, and a frame. It emits no light. To make it read as a moonlit window you
pair it with a cold, dim `LampFixture`.

1. Open `ldtk/Act1World.tscn`.
2. Add a plain `Node2D` child of the root called **`Backdrop`** (once), and
   instance `MoonWindow.tscn` under it.
3. Set its position to a spot on a blank stretch of wall — the art is 48 × 64 px,
   so keep it clear of tiles.
4. Add a `LampFixture` under `Lights` at roughly the same position:

```
light_color  Color(0.62, 0.74, 1.0)   cold moonlight
light_energy 1.3
light_scale  1.6                       ≈ 102 px pool
show_body    false                     the window IS the fixture
```

**Draw order works out on its own, and it is worth knowing why.** Each room
paints an opaque backdrop panel at `z_index -1`; tiles sit at `z 0`. A
`MoonWindow` left at the default `z_index 0` and added in the scene file draws
*after* every `z -1` panel but *before* the rooms (which are instanced at
runtime and so come later in the tree). That lands it exactly where you want:
in front of the wall, behind the tiles. Verified in-engine — don't "fix" it by
setting `z_index = -1`, which would bury it behind the room's own backdrop.

> The moon reads best in a **dim** room. Dropped into an already-bright room its
> glow barely registers, because the fill lights have already raised everything
> around it.

---

## When you add a room in LDtk

Lights are placed at fixed world coordinates in `Act1World.tscn`, but rooms move
when you insert one. **The lights stay put and the rooms slide out from under
them.** This has bitten the project three times: a room ends up with no light at
all, or inherits a light meant for its neighbour.

After adding or moving a room:

1. Re-read the room X ranges (the table above is only true for the current
   layout).
2. Check which lights now fall in which room.
3. Move or add lights, then re-check the seam rule for the *new* neighbours.

---

## Checking your work

Eyeballing a dark room is unreliable. To measure, put the player at a point of
interest and sample a small patch of the rendered frame around it:

- Use a **patch**, not a frame average. Rooms like the cave are mostly solid
  rock, and an average of the whole screen hides everything that matters.
- Watch the **peak** as well as the mean. A peak at 255 means you have blown out
  the highlights; the musical tiles clip easily because the tile art is already
  saturated.

Rough targets from the current build:

| | Mean patch brightness |
| --- | --- |
| Well-lit room | 65 – 90 |
| Feature light (musical tiles) | 55 – 125 |
| Cubicle (deliberately dim) | ~17 |
| Cave, unlit | 4 – 10 |

---

## Gotchas

- **Prototype new lighting in an isolated test scene.** Godot's 2D lights are
  fiddly on the first pass — blend modes, masks, normal maps, energy vs range.
- **`CanvasModulate` is global.** Don't reach for it to fix one room.
- **The exit sign carries its own light** (`ExitSign.tscn`), deliberately dim. A
  "dark" room near an exit will still read around 7–10, not 0.
- **Lights don't move with rooms.** If this keeps costing you time, the fix is to
  make `Lamp` an LDtk entity so lights are placed *in* the room and travel with
  it — a small addition to `tools/ldtk_entities.py` and the entities import hook.
