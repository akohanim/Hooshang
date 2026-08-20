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
- An **office fluorescent** is a `CeilingPanel` — a run of suspended ceiling
  with a flat light panel flush in the grid, for rooms that should read as an
  office rather than as a bulb on a wire. See *Adding a ceiling panel* below.
- The same ceiling can be **painted** rather than placed. Two IntGrid values on
  the `Collisions` layer, next to `brick`: `ceiling` is the room's own roof seen
  from below (what room 2's `CeilingPanel` props are made of), and `ceiling_flor`
  is the same ceiling seen edge on, as a surface to stand on. Both are solid,
  like every other tile on that layer. Panels land every third column and are
  staggered a column per row, so a two-row run reads as a grid rather than as
  vertical pairs.
- **A painted panel cannot glow.** It is a CanvasItem, and `CanvasModulate` 0.05
  takes it to 5% of what was drawn — the trap `SunShaft` and `WallPattern`
  document. The light is a separate thing from the paint, and the import supplies
  it: `scripts/ldtk_level_post_import.gd` hangs a panel light and a weak pool on
  every painted panel cell. Nothing to place for the ordinary case.
- **`CeilingLight`** is an LDtk entity: the light of a panel, on its own. For the
  ones off that rhythm — a lit panel over a doorway, a single fitting in a dark
  room, or a grid you painted whose lights you want somewhere else.
- If a painted run comes through invisible, it is the importer's tile toggle —
  see CLAUDE.md.
- Moonlight is a `MoonWindow` (art) plus a cold `LampFixture` with
  `show_body = false` — the window itself IS the visible source. On the escape
  row that moon is eclipsed and recovering; see *The eclipse* below.
- A screen is `MonitorGlow.tscn`.
- If a corner needs light, ask what would be lighting it, and place that.

**Room 22 is the one exception, and it is deliberate.** It is the last room of
the Act and the only one lit by the sun, and sunlight in a small room genuinely
*is* mostly bounce — so it carries two soft warm fills (`DawnSpillRoom22a/b`)
with no fixture under them. They are still the window's light; they are named for
it so nobody later mistakes them for the old style of anonymous mid-room fill,
and they are kept dim (0.34–0.5) on purpose. The room's darkness is what the sun
shafts are visible *against*: the first pass ran them at 1.15 and 0.85, and the
whole room came up an even warm brown with the beams invisible inside it.

Some props light themselves and need nothing placed next to them:

- **Note tiles** (`scenes/props/note_tile.gd`) carry their own `PointLight2D`.
  It rests at `idle_energy 0.5` so an unstepped pad still announces itself in a
  dark room, and jumps to `lit_energy 1.5` for `lit_time` when the pad sounds,
  easing back down on the same curve as the pad's own flash. The colour is
  sampled from the pad's art and pushed up to full saturation, so re-colouring
  `assets/notes/note_N.png` re-colours its light too — don't set it by hand.
- **Sun shafts** (`scenes/props/lighting/SunShaft.tscn`) are the third kind of
  source, after `LampFixture` and `MonitorGlow`, and the only one you look AT
  rather than by: visible bars of light hanging in the air with dust turning
  over in them. Room 22 is the only user. See *Adding a sun shaft* below.
- **Rumi's gift** (`scripts/ldtk_rumi_trigger.gd`) spawns a mote for the length
  of the beat and frees it. Worth knowing because it is the one case where a
  light was *not* enough: room 1's walls already sit at 255 in the red channel,
  so the mote carries a drawn core (`assets/gift_mote.png`) as well.

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

> **Rooms 1 – 11 were moved +320px right** to open a slot for a new room after
> room 0. The Godot-side nodes in `Act1World.tscn` were moved with them (53 of
> them, x only), so lights still sit over the geometry they were placed on. The
> figures below are the intended layout AFTER the LDtk rooms are moved to match —
> re-measure if the new room ends up a different width than one screen.

| Room | LDtk name | World X | Notes |
| --- | --- | --- | --- |
| 0 | `Level_0` | 0 – 320 | Dim on purpose — the cubicle is a prison |
| — | *(new room)* | 320 – 640 | The slot this move opened up |
| 1 | `Level_3` | 640 – 960 |  |
| 2 | `Level_4` | 928 – 1248 |  |
| 3 | `Level_5` | 1248 – 1568 |  |
| 4 | `Level_6` | 1568 – 1888 | **Cave** — lit at the musical tiles, dark after |
| 5 | `Level_7` | 1888 – 2208 |  |
| 6 | `Level_8` | 2208 – 2528 |  |
| 7 | `Level_9` | 2528 – 2848 |  |
| 8 | `Level_10` | 2848 – 3456 |  |
| 9 | `Level_11` | 3456 – 4064 |  |
| 10 | `Level_12` | 4064 – 4672 |  |
| 11 | `Level_13` | 4672 – 4992 | The Darkshang encounter |

Floor level is around **y = 336**; hanging bulbs sit at **y = 250**.

### The return row (world Y 800 – 992)

Rooms 12 – 21 are the escape: Hooshang runs the office back the way he came,
with Darkshang behind him. They sit on a **second row 640px below the first**,
and they are laid out so each mirrors its outbound twin at very nearly the same
world X — **room N pairs with room 26 − N** (11↔15, 10↔16, … 3↔23).

| Room | LDtk name | World X | Mirrors |
| --- | --- | --- | --- |
| 12 | `Level_14` | 3728 – 4336 | — (entered from room 11) |
| 13 | `Level_15` | 3120 – 3728 | room 9 |
| 14 | `Level_16` | 2512 – 3120 | room 8 |
| 15 | `Level_17` | 2192 – 2512 | room 7 |
| 16 | `Level_18` | 1872 – 2192 | room 6 |
| 17 | `Level_19` | 1552 – 1872 | room 5 |
| 18 | `Level_20` | 1232 – 1552 | room 4 — **dark**, like its twin |
| 19 | `Level_21` | 912 – 1232 | room 3 |
| 20 | `Level_22` | 592 – 912 | room 2 |
| 21 | `Level_23` | 272 – 592 | room 1 |
| 22 | `Level_24` | −48 – 272 | room 0 — **the cubicle**, and the only room in the Act lit by daylight |

Room 22 is a byte-for-byte copy of room 0's geometry, one row down and 48px
left: the same cubicle he woke up in, at the end of the night. Its open band is
world **x 0 – 224, y 816 – 896** — five tiles tall, so there is much less room
above the floor than the numbers for the top row suggest. Nothing lies to its
LEFT (it is the leftmost room in the world), so the seam rule below only has to
be satisfied on the right, against room 21 at x = 272.

Its lighting was **duplicated from the outbound row**: same X, same
colour/energy/scale/cable, `y + 640`. So the return trip is lit exactly like the
way in, which is the point — you are meant to recognise the rooms. Ceiling
fixtures, moon glows and moon windows all came across; rooms 13 and 14 were lit
by hand first and were left alone.

### The eclipse (rooms 13 – 22)

The escape row runs a **total eclipse that recovers**. Room 12 is a blood moon
with the umbra still across most of it and a cold violet halo; by room 21 the
disc is clear and warm and its glow is the colour of the sunrise waiting in room
22. The ramp is the visual spine of the escape — you should be able to tell
roughly how far out you are by looking at the window.

It is **six numbers per window**, not seven drawn moons. `MoonWindow` tints the
one `moon.png` and lays two white alpha masks over it
(`tools/gen_eclipse_moon.py`): `Shadow` is the umbra, `Halo` is the ring of lit
air. Both take their colour from the instance, so the whole ramp reads as a
column in `Act1World.tscn` instead of hiding in ten PNGs nobody can compare.

| Room | `shadow_amount` | `halo_amount` | Moon | Glow colour | energy / scale |
| --- | --- | --- | --- | --- | --- |
| 12 | 0.85 | 0.75 | deep crimson | blood red | 1.9 / 2.8 |
| 13 | 0.72 | 0.70 | crimson | | 1.9 / 3.0 |
| 14 | 0.60 | 0.64 | red | | 2.2 / 3.2 |
| 15 | 0.48 | 0.58 | red-orange | | 2.4 / 2.4 |
| 17 | 0.30 | 0.48 | orange | | 1.6 / 1.8 |
| 18 | 0.20 | 0.44 | warm orange | | 2.6 / 2.4 |
| 21 | 0.05 | 0.38 | amber | warm amber | 3.2 / 3.0 |

**Rooms 16, 19 and 20 have no moon window** and are untouched by this. The row
was only ever given seven, and the ramp still reads across the gaps.

Four things worth knowing before retuning it:

- **The sky patch is not allowed to go black.** It started at `(0.055, 0.03,
  0.105)`, which is darker than the brick wall outside the window — so sitting in
  the same 1.9-energy light the wall came up red and the sky stayed at nothing,
  and the window read as a hole punched in the wall rather than as a night sky
  behind it. It now ramps `(0.125, 0.052, 0.125)` → `(0.205, 0.10, 0.13)`. The
  band below the moon measures **min 23, mean 40** luminance against the moon's
  **mean 79, peak 133** — dark enough to stay night, light enough to be sky, and
  the moon still comfortably the brightest thing in the frame.

- **`MoonWindow`'s defaults are the plain full moon**, so rooms 1 – 11 are
  unaffected — still the same night seen on the way in, cold and blue. Keep it
  that way: the eclipse only means anything because the outbound trip had none.
- **Keep green well below red in `moon_color`.** `moon.png`'s craters are blue,
  so a yellow tint (high green, low blue) turns them olive and the moon comes out
  looking mouldy rather than warm. Room 21 is `(1, 0.62, 0.38)` for that reason
  and not `(1, 0.76, 0.44)`, which was tried first and looked mossy.
- **The glows used to be `3.0 / 5.0` across the board**, which is a 320px radius
  in a 320px room — it floods wall to wall and leaves nothing dark for the moon
  to be a light *in*. Room 12 was a flat red screen with no shadow anywhere and
  the eclipse art was invisible inside it (mean 55.8, peak 173 — bright and
  completely without contrast). They now ramp from a tight pool in room 12 to
  something near the old flood in room 21, which is most of what makes the row
  read as getting less gloomy.

- **The halo is a bright RING plus a broad dim WASH**, and it needs both. The
  ring alone hugged the limb and stopped, leaving the corners and the whole band
  below the moon unlit — the other half of the same "hole in the wall" problem.
  Its canvas is 96px rather than the shadow's 64 for that reason: at 64 it could
  not reach past 16 window px from the moon's centre, and the sky patch extends
  31px below it. `HALO_REACH` (42px, i.e. 21 window px) is a hard stop, because
  the moon sits 3px right of the frame's middle and anything wider escapes the
  frame and glows on the brick outside the window.

`EclipseChillRoom12/13/14` are a cold violet rim right at the window, fading out
over three rooms. The red of a blood moon is light bent through the Earth's
atmosphere; this is the part of the shadow that stays cold, and it is what makes
room 12 read as *wrong* rather than merely red. Small radius on purpose — each
sits well inside its own room, unlike the moon glows underneath them.

A moon window is **two nodes that must stay together**: `MoonWindowRoom<N>` is
the window art under `Backdrop`, and `MoonGlowRoom<N>` is its light under
`Lights`. They share an X — the glow is the moonlight coming through that
window, so moving one without the other lights a blank wall.

Two things to know before editing them:

- **The pairing is off by 16px** (48px for room 1 ↔ 21), because the return row
  is not perfectly aligned with the outbound one. The copies kept their X, so
  they sit a few pixels further into the room than their twins do. Under a tile
  everywhere but room 21.
- **Twenty of the thirty reach past a room seam**, exactly as their originals
  do. That is inherited, not a mistake — but it means the trap below applies
  when you retune one.

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

**Name it for the room it serves**, and number it the way the room is numbered.
Every fixture is `<Kind>Room<N><letter>`, where N is the LDtk level number and
the letters run left to right across the room: `CeilingRoom8a`, `CeilingRoom8b`,
`CeilingRoom8c`. Ceiling fixtures always carry a letter even when there is only
one of them, because they are the ones that come in runs. Other kinds take a
letter only when a room has more than one to tell apart — `MoonGlowRoom7`,
`TileLampRoom4`, `SpawnMonitorRoom5`, `CubicleBulbRoom0`.

These names are how you tell what is now in the wrong place, which only works if
they agree with the rooms. **Rooms get renumbered when you insert one** — the
level identifiers are the play order — so re-letter the lights in that room at
the same time, or the next person reads `CeilingRoom9d` and looks in room 9.

That has already happened once, and it is worth knowing what it cost. Eight
ceiling fixtures in the outbound row still carry a name from before a renumber —
`CeilingRoom7a2` sits in room 8, `CeilingRoom8b2`…`8g2` sit in room 9,
`CeilingRoom8c3`/`8g3` in room 10. **Every top-row moon window is worse**: they
are named one room too high across the board (`MoonWindowRoom2` is in room 1,
`Room6` in room 5, `Room8` in room 7, `Room9` in room 8, `Room10` in room 9)
while the glows beside them are named correctly — so the two halves of the same
window disagree about which room they are in.

Nothing is broken by it: a light is placed in world coordinates and does not
care what it is called. But it made duplicating the row into the return trip a
job that had to group the lights **by position**, because grouping them by name
would have copied the drift into ten new rooms. Trust the coordinates over the
name, and fix the name when you find one lying.

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
  cold Color(0.62, 0.74, 1.0), placed on a MoonWindow — rooms 1-11

Blood moon              energy 1.9   scale 2.8   show_body false
  Color(0.86, 0.16, 0.26) + a violet EclipseChill on top — room 12, the
  gloomiest end of the escape ramp; see The eclipse above

Monitor (MonitorGlow)   energy 0.9-1.1   scale 1.0-1.2
  cold Color(0.55, 0.78, 0.95); glows/wanders slowly by default

Feature light           energy 1.6   scale 1.3   show_body true
  e.g. over the musical tiles in the cave

Office ceiling panel    energy 1.4   scale 1.9   panel_energy 1.6   run 5
  CeilingPanel at the ceiling line (y 172), cold Color(0.83, 0.9, 0.95).
  pool_drop 50 is what lets a 122px pool reach a floor 164px below it

Failing panel           energy 0.7   scale 1.55  panel_energy 1.3   run 3
  + flickers 0.55 at speed 11, Color(0.86, 0.92, 0.82) — room 2's middle

Dead panel              energy 0     panel_energy 0
  the frame still in the grid, nothing coming out of it. Needs another light
  near it or there is nothing to see; room 2 leaves one over the drop

Dawn window             energy 2.6   scale 1.25  show_body false
  warm Color(1, 0.72, 0.42), placed on a DawnWindow — room 23 only

Dying fluorescent       energy 0.6   scale 1.3   cable 36   show_body true
  cold Color(0.86, 0.92, 0.82) + flickers 0.55 at speed 11
  the office light losing to the sunrise; room 23's twin of the cubicle bulb
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

### The dawn window

`scenes/props/backdrop/DawnWindow.tscn` is the same thing for room 23, and it is
built to be interchangeable with `MoonWindow`: the same 48 × 64 `window_frame.png`
over a 40 × 54 sky, so it reads as *the same window* he has walked past twenty
times, with the night finished behind it. The sky is art
(`tools/gen_dawn_window.py`) rather than a `ColorRect`, because a sunrise is a
vertical ramp and flattening it to one colour is the difference between a sunrise
and someone leaving an orange light on.

Pair it the same way — a warm `LampFixture`, `show_body = false` — and see the
Dawn window recipe above.

---

## Adding a ceiling panel

`scenes/props/lighting/CeilingPanel.tscn` is the office fluorescent, and it is
not hung from the ceiling — it **is** the ceiling: T-bar grid, acoustic tiles,
and one cell where a flat luminous panel sits flush where a tile would be.

It **extends `LampFixture`**, so colour, energy, pool size, the `lights` group
and the flicker all come from there and cannot drift. Place it on the room's
ceiling line — **y 172** in the top row, the 8px band just under the ceiling
tiles — with three exports of its own:

```
run_tiles     cells of ceiling to lay, panel included. Forced ODD: the panel is
              the MIDDLE cell, so the position you place is the light and the
              grid grows evenly either side of it
panel_energy  how bright the panel's FACE reads, separate from the pool
pool_drop     how far below the ceiling the room pool is centred
```

`pool_drop` is the one honest fudge, and it is the same trade this guide already
makes for hanging lamps. A panel in the ceiling is ~164px above the floor, so a
pool centred on it needs a 164px radius to reach the ground — wider than half a
room, straight through the seam into the room next door. Dropping the POOL and
not the fixture keeps the reach honest and the rooms independent; the panel is
still visibly the thing the light comes from.

**The panel's glow is a light, not a sprite.** `CanvasModulate` is 0.05 and
multiplies every CanvasItem, so a painted luminous panel arrives at 5% of what
was drawn — the same trap `SunShaft` and `WallPattern` document. The glow is a
`PointLight2D` wearing `assets/props/ceiling/ceiling_light_glow.png`: the shape
is art, the brightness is light. The tiles either side are ordinary paint, lit
by the panel between them, which is what a dark office ceiling actually looks
like.

Because the glow is a light, **the flicker reaches it for free** — the prop reads
the pool's energy back each frame rather than recomputing the waveform, so the
two cannot drift. A panel whose pool stutters while its face burns steadily reads
as a bug in the game rather than a fault in the building.

`light_energy = 0` with `panel_energy = 0` gives a **dead panel**: the frame is
still in the grid and nothing comes out of it. It needs another light near it or
there is nothing to see — which is the point of leaving one where the moon can
find it.

Art: `tools/gen_ceiling_panel.py`, three files on the same 24x8 cell
`tools/gen_platforms.py` uses, so the ceiling above him and the ceiling he ends
up standing on are the same ceiling.

---

## Adding a sun shaft

`scenes/props/lighting/SunShaft.tscn` draws the light itself: parallel bars
falling from a window with dust drifting in them. Instance it under `Lights` and
put it where the window is.

**The beams are lights, not painted shapes**, and they have to be.
`CanvasModulate` is 0.05 and multiplies every `CanvasItem`, so a translucent
polygon laid over the room comes out at a twentieth of what you drew. A
`PointLight2D` with a beam texture (`tools/gen_light_shaft.py`) is exempt for
exactly the same reason every lamp is — and it lights the floor it lands on for
free.

**The motes are not lights**, and that is also the point. They are an ordinary
particle sprite, lit by the beams like anything else in the room, so a mote is
bright inside a beam and invisible between them with nothing masking or clipping
it. The emitter is one plain box across the whole fan.

| Export | What it does |
| --- | --- |
| `beam_color` / `beam_energy` | As a lamp. Runs hot (≈1.9–2.1) because it is doing two jobs: being visible as air, and lighting what it lands on |
| `beam_scale` | Length **and** width together. The texture's beam is 128px, so reach = `128 × beam_scale` |
| `angle_degrees` | Measured from straight down; positive tips the beams to the left. Set this rather than rotating the node, so the node's position stays "where the window is" |
| `beam_count` / `beam_spacing` | How many bars and the gap across them. Match the window: the panes either side of a mullion make two |
| `beam_falloff` | How much dimmer each bar is than the last. Identical bars read as a stencil |
| `mote_*` | Count, lifetime and drift of the dust |

Two things learned tuning room 22's, both worth not repeating:

- **Beams merge.** The first beam texture was 9→22px half-width; at three bars
  spaced 22px they overlapped into one broad wedge with no frame-shadow in it at
  all. The texture is now 6→14, which is what makes the gaps read.
- **A bright room eats them.** A shaft is additive, so it only shows against dark
  air. If the beams look weak, turn the room's fill DOWN before turning the beam
  up.

---

## Adding a Persian wall pattern

`scenes/props/backdrop/WallPattern.tscn` is a rosette that surfaces out of the
wall, drifts through a colour and sinks back. Instance it under `Backdrop` in
`ldtk/Act1World.tscn`, at the point on the wall you want it.

**It is a light, like everything else here.** `CanvasModulate` is 0.05 and
multiplies every CanvasItem, so a pattern painted on the backdrop would arrive at
a twentieth of what was drawn — the same reason the sun shafts are lights
(above). The cookie is white with the ornament in its ALPHA
(`tools/gen_persian_glyph.py`), so the colour is the light's own and one texture
covers the whole palette it cycles.

**It only touches the wall, and that is what makes it read as being IN the
wall.** `range_item_cull_mask` is 2, a bit that only the room backdrop carries
(`LdtkWorld._add_backdrop` sets `light_mask = 1 | 2`, an OR, so ordinary lamps
still light the backdrop through bit 1). Without the filter it washes over the
brickwork, the props and Hooshang himself, and reads as a coloured spotlight
somebody left on.

**Place it clear of the room's window.** The first pass put five of six directly
behind a `MoonWindow` and the frame ate the middle of every rosette. The glyph
spans `128 x pattern_scale` px — about 115 at the default — so leave that much
between it and anything drawn on top of the wall.

| Export | What it does |
| --- | --- |
| `hues` | The palette, one per appearance. It drifts toward the next WHILE it is up, so the rosette changes colour as you watch rather than between visits |
| `peak_energy` | Brightness at the top. 0.62 default, and low on purpose — this is scenery, not a fixture |
| `pattern_scale` | Size. 0.9 in the placed instances |
| `bloom_time` / `hold_time` / `fade_time` / `rest_time` | The cycle. `rest_time` is the honest knob for "how often is this on screen" — reach for it before `peak_energy`, which is what stops it reading as a wall |
| `spin_speed` | Degrees per second. Eightfold symmetry returns every 45 degrees, so a crawl is plenty |
| `phase` | Seconds to start this instance into its cycle. **Set it per instance** or neighbouring rooms breathe in step |

Six are placed, spread across the Act: rooms 1, 5, 9 on the way down and 14, 18,
21 on the way out, with phases that are not multiples of each other so no two
ever come up together.

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

Eyeballing a dark room is unreliable. `tests/room_shot.tscn` stands the player in
a room, photographs the 320×180 game surface and prints the frame's mean and peak
luminance — which is how room 22's dawn was balanced:

```bash
/Users/ari/Downloads/Godot.app/Contents/MacOS/Godot --path . res://tests/room_shot.tscn -- Level_24
```

It runs windowed (2D does not rasterise headless), binds no save slot, and writes
to `user://shots/`. To measure by hand instead, put the player at a point of
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
| Room 22 at dawn (whole frame) | ~36 |
| Cave, unlit | 4 – 10 |

Room 22 sits well under "well lit" on purpose. It is a *contrast* room, not a
bright one: the number that matters there is the range between the dark air at
the far end and the sun in the window, not the average.

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
