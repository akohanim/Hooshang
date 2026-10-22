# Act 2 finale poses

Cutscene-only visual double based on the approved native 18px adult movement
art. The shared player source, SpriteFrames and controller are unchanged.

Edit `source/finale.aseprite` and `source/coat.aseprite` in Aseprite, then run
`python3 tools/export_act2_finale.py`. This exports PNG/JSON/SpriteFrames without
regenerating the editable source. `tools/build_act2_finale_poses.lua` records the
initial construction; its explicit `rebuild=yes` option overwrites hand edits.

Clips: pickup, paint, salute, idle, walk_home, pickup_coat, paint_idle.
Painting and walking loop. The final hand tint comes from the existing poem's
ink; head, body and movement silhouettes reuse the approved adult artwork.
The folded coat uses that outfit's palette. Runtime choreography lives in
`scenes/props/act2_ending/Act2Ending.tscn` and its adjacent scripts.

`source/farewell.aseprite` is the separate native 18px adult hold, hand release,
and quiet fall. It replaces the child's farewell double when the dream drains
away, before the waking pond. Export saved edits with
`python3 tools/export_child_farewell.py --adult`. The one-time construction
recipe is `tools/build_adult_farewell.lua`; it never edits shared movement art.
