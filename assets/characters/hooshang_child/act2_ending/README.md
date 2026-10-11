# Carpet farewell poses

`source/farewell.aseprite` is an ending-only copy of the approved child's
hanging pose, with hands lowering through a six-frame release. Head, torso,
legs and palette come from the original art. No shared movement asset changes.

Edit this Aseprite source, then run `python3 tools/export_child_farewell.py`.
The exporter updates the PNG, JSON and SpriteFrames while preserving edits.
`tools/build_child_farewell.lua` records initial construction; its explicit
`rebuild=yes` option replaces hand edits and is not the ordinary export path.

The cutscene uses hold, release and fall_rest. The sprite inherits the player's
visual scale/offset but has no collision or gameplay movement state.
