# Validation — 2026-09-23

Act 3 import and focused art test: PASS. The saved world contains the new
408-tile atlas; the real import builders select the new thought, spike and
ladder art from LDtk defaults; all eight spike facings carry red outlines;
thought rims remain red; older projects keep their default palette.

Native PNG palette/dimension checks: PASS. Terrain and ladder use black/white;
thoughts add hot red. Runtime assets use binary alpha.

The project-required scene suite plus the new art test and two ladder checks
finished with **31 / 39 passing**. These eight were not clean:

- `backtrack_test`: exits 0, but emits missing `swell`/`portrait_side` calls
  on null dialogue objects in DashTutorial.
- `conveyor_test`: two displacement/airborne-rider assertions fail.
- `intro_test`: expected dialogue sequence differs from the current story.
- `slide_test`: three jumping/respawn assertions fail.
- `death_test`, `jump_tutorial_test`, `pause_test`, `ladder_overhaul_test`:
  exceeded the 150-second per-scene limit.

No clean baseline comparison was performed; these results do not establish
when the broader failures were introduced. Unrelated gameplay was not edited
to force those checks to pass.

Additional verification: LDtk import isolation passes in both import orders.
Cone spike tests were rerun after adding the Act 3 spike sheets and pass.
The final expanded Act 3 art test passes. Godot editor import runs also emit
resource/RID cleanup warnings at exit; the final focused art check exits cleanly.

Full regression logs for this session: `/tmp/hooshang_act3_tests/`.

## Connected paint follow-up

`python3 tools/test_act3_connected_terrain.py`: PASS for 2,560 neighbor
configurations across the eight new brushes and two legacy ceiling values.
This verifies the serialized LDtk rules select all 47 connected shapes,
including inside corners, opposite edges and isolated cells, with no border
at a connection to another material. All eight deep-fill tiles are identical.
Paint/erase/repaint checks prove neighboring rims update, removed cells leave
no art, and cached tiles retain LDtk's `[rule_uid, linear_cell_id]` addressing.
Reinstalling leaves rule IDs, room caches and project data unchanged.

Authored IntGrid geometry matches the original Act 3 project. The final Godot
art test loads all 408 tiles and still verifies the red hazard variants.
Follow-up Godot checks all pass: `act3_art_test`, `smoke_test`,
`world_bounds_test`, `forward_entry_test`, and `thought_tiles_test`.
Their logs are `/tmp/act3_connected_<test_name>.log`.

## Initialized starter room

`Act3_Level_0` now deliberately has showcase geometry instead of the original
empty shell. `act3_showcase_test.tscn` passes in a rendered Godot run: the room
loads, the player settles safely on the floor with zero deaths, and both
thoughts, the ladder and spike strip import with Act 3 art. The capture is
`showcase_room.png`. The connected-paint regression and `act3_art_test` also
pass after initializing and reimporting the room.

## Minimal three-brush revision

Active terrain brushes are now brick, grass and scaffolding only. Retired
brushes map to brick without changing occupied cells. Compared the final
project with the saved pre-edit snapshot: every room's occupancy and every
entity placement are unchanged.

The connected-paint test passes all 768 neighbor configurations, checks that
deep interiors contain only opaque black, and verifies paint/erase behavior.
The final Godot art and rendered showcase checks pass; `showcase_room.png`
shows the current edited room with the minimal artwork. Red hazard art is
unchanged.

## Sparse structural interior revision

The three brushes now place two variants of masonry joints, grass roots and
scaffold braces through deterministic LDtk modulo rules. Accents are staggered
at material-specific densities and limited to the outer two cells of a mass;
the shared deep-fill tiles remain black. Regression checks verify both variants
actually appear, remain sparse, and do not enter deep interiors. Paint/erase,
all 768 neighbor configurations and installer idempotence still pass.
The revised atlas contains 690 logical tiles in 696 allocated atlas slots.
Final Godot art/import and showcase checks pass. A forced rendered capture
verifies the revised room; this also avoids a stalled `frame_post_draw` wait
when the macOS game window is occluded. Authored IntGrid values and all entity
placements match the pre-revision snapshot exactly.
