# Opening office

Level_0 art pass: cool woven partition, pinned notes and calendar, grounded desk,
coffee and paperwork, a late-night clock, warm pendant light and sparse moonlit
motes. All geometry is decorative. The existing player start, solids, door and
story triggers remain authored in LDtk.

OpeningOffice is instanced under Act1World/Props at Level_0's origin (-880, 160),
using the same world-space placement convention as the existing cubicle. Move
this instance with the cubicle if the room is relocated in LDtk. The procedural
pixel details live in opening_office.gd; lighting controls are prefab overrides
in OpeningOffice.tscn. This survives LDtk reimports.

Render the actual spawn, after the opening fade, with:
Godot --path . res://tests/opening_room_shot.tscn
The preview is written to output/opening_room.png at nearest-neighbour 4x.
