# Lighting — a working guide

How to light rooms in this project by hand, and the handful of rules that stop
it going wrong. Everything here is 2D lighting: `CanvasModulate` for darkness,
`PointLight2D` (wrapped in `LampFixture.tscn`) for light.

---

## The style: every light has a visible source

Act I is an office at night, so the lighting is **diegetic** — you should always
be able to point at what is emitting it. Hanging fluorescent tubes, the moon
through a window, a monitor left on. There are no invisible "fill" lights parked
mid-room any more; the look comes from pools of light with genuinely dark corners
between them, which is the point.

Practically that means:

- A ceiling fixture is a `LampFixture` with `show_body = true`, so you see the
  cord and bulb.
- Moonlight is a `MoonWindow` (art) plus a cold `LampFixture` with
  `show_body = false` — the window itself IS the visible source.
- A screen is `MonitorGlow.tscn`.
- If a corner needs light, ask what would be lighting it, and place that.

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
| `light_energy` | Brightness. Ceiling fixtures ~1.7, the cubicle bulb 2.1 |
| `light_scale` | **Size of the pool** — see the radius formula below |
| `show_body` | `true` draws the physical cable + bulb — the default for a fixture. `false` only for a source that is already visible as art, e.g. moonlight on a window |
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
lights** rather than one big one — or hang the bulb lower, which shrinks the
radius you need (see *How a hanging fixture is positioned*).

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

Floor level is around **y = 336**; hanging bulbs sit at **y = 250**.

> These shift whenever you add or move a room in LDtk. Re-check them before
> placing anything — see *When you add a room* below.

---

## Finding the position to place something

**You can place lights visually.** `ldtk/Act1World.tscn` has an **`EditorPreview`**
node at the bottom of the tree — a real instance of the imported world, there so
the rooms are visible in the editor and lights can be dragged onto actual
geometry. `LdtkWorld` deletes it the instant the game starts, in `_enter_tree()`,
before its contents ever wake up.

**Leave it alone**: don't rename, move or delete it, and don't add anything
inside it. Put lights under `Lights` as usual.

(A `@tool` script that generated the preview at edit time was tried first and
does not work — nodes a tool script adds at runtime never show in the Scene dock,
so there is nothing to drag against.)

Do **not** drag `ldtk/levels/*.scn` into the scene to see the map. Those are
generated imports, and parenting one into `Act1World` puts a second copy of that
room at the world origin, on top of room 1, with live collision.

If you would rather work in numbers, two ways to get them:

**1. Walk there and read it off.** Run the game, press **F3**, and the debug
overlay's first line is the player's world position. Stand where you want the
thing and note the number. Easiest method by far.

**2. Do the arithmetic from LDtk.** An entity's `px` in LDtk is local to its
level, so:

```
world position = room world origin + local px
```

Room 1's origin is `(0, 160)`, so its Exit at local `(264, 96)` is world
`(264, 256)`. Room origins are in the table above.

Useful landmarks in room 1 (the opening scene):

| | World position |
| --- | --- |
| PlayerStart | (72, 248) |
| RumiTrigger | (216, 232) |
| Door | (250, 227) |
| Exit trigger | (264, 256) |
| **ExitSign** | **(264, 220)** |

## Adding a light fixture

1. Open `ldtk/Act1World.tscn`.
2. Select the **`Lights`** node.
3. Drag `scenes/props/lighting/LampFixture.tscn` from the FileSystem dock onto
   it (or **Ctrl/Cmd + Shift + A** → Instance Child Scene).
4. Set **Transform → Position** to a world coordinate inside the target room.
5. Set the exports in the Inspector. For a standard room fixture:
   `light_energy 1.7`, `light_scale 1.5`, `cable_length 74`, `show_body true`.
6. Check the radius against the seam rule above.
7. Run it — pick the room straight from the debug picker (F5), no need to play
   up to it.

**Name it for the room it serves.** The convention in the scene is
`CeilingRoomNa` / `CeilingRoomNb` for room fixtures, and a descriptive name for
anything else (`CubicleBulb`, `MoonGlowRoom2`, `TileLampRoom5`,
`SpawnMonitorRoom6`). When rooms shift, these names are how you tell what is now
in the wrong place.

### How a hanging fixture is positioned

**The node's position is the BULB, and the cable is drawn upward from it to the
ceiling.** So you place the lamp where the light should be, and set
`cable_length` to the distance back up to the ceiling:

```
cable_length = bulb_y − ceiling_y
```

Rooms start at y = 160 and the ceiling tile is one 16 px cell, so the ceiling
underside is **y = 176**. Floor is **y = 336**.

Hang bulbs LOW — around **y = 250**, `cable_length = 74`. That matters for more
than looks: a bulb at 250 only needs an 86 px reach to light the floor
(`light_scale 1.5`, radius 96), whereas one tucked up at the ceiling needs a
160 px radius to do the same job — and that wide a pool spills straight through
the seam into the next room. **Hanging lower is what keeps rooms independent.**

This is a real trap: the first pass at this put lamps at y = 178 with radius 115,
which cannot reach a floor 158 px below. Three rooms measured 0–5 brightness at
floor level — effectively black.

### Recipes

```
Hanging ceiling lamp    energy 1.7   scale 1.5   cable 74   show_body true
  bulb at y 250, ceiling y 176 — the standard room fixture

Cubicle bulb            energy 2.1   scale 2.2   cable 40   show_body true
  + flickers, warm Color(1, 0.87, 0.66) — deliberately the dimmest room

Moonlight               energy 1.3   scale 1.6   show_body false
  cold Color(0.62, 0.74, 1.0), placed on a MoonWindow

Monitor (MonitorGlow)   energy 0.9-1.1   scale 1.0-1.2
  cold Color(0.55, 0.78, 0.95); glows/wanders slowly by default

Feature light           energy 1.6   scale 1.3   show_body true
  e.g. over the musical tiles in the cave
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
