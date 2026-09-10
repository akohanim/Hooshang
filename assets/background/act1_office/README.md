# Act I office backgrounds

Every one of the 34 authored Act I rooms has a distinct native-resolution
pixel-art back wall, including the six inserted V rooms and both test rooms.
The first ten numbered rooms retain their existing art.

## Visual progression

- Outbound rooms: restrained office panels, records cabinets, mail handling,
  administrative corridors and vertical service wells.
- Level_14: the Darkshang reveal begins in a mostly intact office. Its original
  two animated eclipse windows and paired lights still turn together.
- Levels 15–18: cracks become missing panels, dangling ceiling sections,
  loose conduits and damaged office furniture.
- Levels 19–24: torn cladding, exposed studs, broken ceiling grids, fallen
  plaster and crushed cabinets progressively overtake the office. The dark
  puzzle/chase rooms retain black ambient and the existing earned player glow.
- Level_25: warm dawn on the familiar cubicle, with damage around its edges.
  The original cubicle, dawn window, monitor, bulbs, spill and sun shafts are
  unchanged. The chase/collapse timing remains owned by Act1Beats.

The original return moon colour/umbra ramp is preserved. The added windows in
22 and 23 interpolate its warm late-night colours before 24 and dawn at 25.
No new window is added to a musical-puzzle room. Existing story lighting stays
as authored, including the dark return rooms' original fixtures.

## Art and integration

Built-in ImageGen generated each source separately. `source/` retains those
originals; `prompts.json` records the first ten prompts and
`remaining_prompts.json` records the remaining 24. `remaining_rooms.json`
records their design briefs. There are no baked moons or windows in the new
24 sources: real window prefabs provide the sky, lunar phases and lighting.

Rebuild textures:

```
python3 tools/prepare_act1_office_backgrounds.py
python3 tools/prepare_act1_remaining_backgrounds.py
```

The remaining-room builder reads dimensions from LDtk, fits source height
without distorting proportions, and continues very wide rooms in reflected
architectural bays. Textures use nearest sampling and 64-colour palettes.
`tools/install_act1_remaining_backgrounds.py` is the one-time scene installer;
it deliberately refuses a second installation.

`Act1World.room_backdrop_overrides` maps exact identifiers to textures.
Overrides suppress old imported `BG Image` nodes. All walls remain shaded,
obey CanvasModulate, and use NEAREST filtering. `room_backdrop_tints` lowers wall reflectance in the brightest corridors without
changing any fixture, child window or gameplay item. Gameplay geometry is unchanged.

## One moon per camera

`MoonVisibility` selects at most one lunar disc per viewport immediately
before drawing, holding its choice until that disc leaves the frame.
OfficeMoon and MoonWindow register automatically. Other windows keep their
sky and frame. Hidden lunar instances continue updating their eclipse state.

The first seven backgrounds contain painted discs. Their `room_moon_regions`
rectangles let `moonless_wall.gdshader` remove the painted copies, including
outline pixels. The selected OfficeMoon alone draws its luminous core/halo
and enables its small pool. This survives the compatibility light limit.

Future backgrounds must use a moon prefab; register any already-painted discs
with `room_moon_regions` and a backdrop override. Do not bake unregistered
moons into repeating art.

## Verification

- `act1_all_backgrounds_test.tscn`: complete room coverage, unique textures,
  native sizes, filtering, puzzle darkness, original eclipse/dawn contracts.
- `act1_all_backgrounds_shot.tscn` (windowed): every room plus eclipse stages;
  outputs `output/act1_office/all_rooms/`. Story overlays are omitted for art
  review; return-room player glow is granted as it is by Act1Beats.
- `single_moon_test.tscn`: camera sweep and future prefab registration.
- `office_background_test.tscn`: original ten-room integration.
- `office_moon_render_test.tscn` (windowed): luminous core under black ambient
  and actual nearby-surface illumination.
- `chase_route_test.tscn` and `collapse_test.tscn`: original story behaviour.
