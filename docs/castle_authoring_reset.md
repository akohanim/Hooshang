# Castle authoring reset

The user's new direction supersedes the precision-puzzle build: the castle is
an empty authoring shell for manual LDtk design, not a completed puzzle route.

## Editable source and scope

Open `ldtk/hooshang_act2.ldtk`. All17 `Prison_*` rooms keep their identifiers,
IIDs, dimensions, map positions and20 undirected room connections. All22 other
Act2 room dictionaries are unchanged. Act1 and the player controller were not
edited.

Removed interior solid/one-way platforms, spikes, water, patrols, collapsing
platforms, switches, levers, pressure plates, musical tiles, gates, shortcut-door
locks, signs and decorative furniture. Their definitions and artwork remain
available in LDtk for reuse. Kept outer walls, a plain wall background, room
spawn markers and the castle passage. The cage, Jamshid and four keys remain as
movable anchors, lowered to the new shell floor. These can be repositioned while
designing. No flags were added.

The only remaining interior terrain is the threshold ledges. There are no
replacement puzzle routes or stairs through the empty rooms: reaching high
connections from the floor is intentionally left to the user's level design.
Connection tests stage the player at those thresholds, not at the room entrance.

Backup: `output/castle_authoring_reset/before.ldtk`. The reset script
`tools/clear_castle_interiors.py` is a one-time migration and refuses to overwrite
its backup. Do not rerun old challenge generators against the emptied project.
The previous precision ZIP is historical and does not represent this reset.

## Celeste connection analysis

Read the locally installed `3-CelestialResort.bin` through the existing binary
reader, without launching Celeste or extracting its artwork. Measured examples:

- `02-b` has a16px jumpThru at(168,168) in a184px-high room,16px above the bottom.
  The adjoining lower room `02-a` has16px supports at(152,24) and(168,48).
- `04-b` has a16px ledge at(152,168). Below it, `03-a` has a24px support at
  (456,24) and a16px support at(472,40); their different room origins align
  these near the same world-space connection.
- `04-d` has a16px ledge at(48,168); the lower `04-c` has16px supports at
  (48,32) and(32,56).

These are entity coordinates and geometric adjacency candidates. They support
using small receiving ledges just inside the room and separate lower launch
supports. Binary placement alone does not prove Celeste's runtime transition
rules, exact collision behavior or universal two-way accessibility.

Adaptation: all10 vertical castle connections have a16px wooden catch ledge
16px above the upper room's bottom, plus a16px launch/receiving ledge24px below
the lower room's top. The40px opening keeps24px clear beside each ledge. Jump
through the support from below, land above, then step into the open half and
release horizontal input to descend. Solid scaffolding is never used for these
jump-through supports. The formerly flooded basement seam now uses the same
arrangement because its interior water was removed.

Evidence: `output/castle_authoring_reset/resort_jumpthrus.json`,
`resort_vertical_candidates.json`, `connections.json`, `ledges.json` and
`routes.json`. The final10 upward landings and10 return descents use actual
jump/walk inputs after staging at the connection, with zero failures/deaths.

## Character refinement

Both saved child Aseprite sources have narrower silhouettes across all63 frames,
with the same24 tag ranges and durations. Sitting now uses an upright head,
visible torso, hands in front and bent legs instead of the folded crouching pose.
Jamshid's rod grip was lowered to the seated hands. Clothes, hair colours,
standing height, runtime scale, collisions, movement and dialogue are preserved.

Sources:
- `assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite`
- `assets/characters/jamshid/aseprite/jamshid_child_movement.aseprite`

Continue normal hand edits in Aseprite and export with
`tools/build_child_hooshang_frames.py` and `tools/import_jamshid_aseprite.py`.
The `refine_child_*` scripts are one-time authoring recipes, not exporters.
Original sources are archived beside the LDtk backup as
`hooshang_child_before.aseprite` and `jamshid_before.aseprite`.

## Verification

Official LDtk1.5.3 schema validation passes. Structural checks prove17 cleared
interiors, unchanged map metadata and connections, no internal hazards/water or
mechanisms, and unchanged22 non-prison rooms. See `validation.json`.

Rendered tests check126 Hooshang and130 Jamshid pose/facing combinations with
zero exposed coloured edges. Final child animation checks pass:15px standing
height, frame bounds, two-pose stride, seated playback and swim presentation.
Movement smoke, world bounds, Jamshid animation parity, the fishing encounter,
and keyboard/staging dialogue skips pass. Initial outline/height failures were
fixed in the source and re-exported; their logs remain separate from final runs.

`castle_empty_portals_test` stages all40 directed threshold crossings and checks
arrival, idle and respawn. The new blank-room fixture replaces old expectations
of key-gated shortcut doors. The removed puzzle route tests are historical.

Rendered captures: `output/castle_authoring_reset/fishing_standing.png`,
`fishing_seated.png`, `Prison_Hub.png`, and one image for each cleared room.
These are staged rendered inspections, not a full gameplay route through the
empty authoring shells. Subjective character aesthetics remain open to review.
