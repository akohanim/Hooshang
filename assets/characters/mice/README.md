# Act III vine mice

The black and white mice derive from the approved ImageGen pixel draft in
`source/concept.png`; full prompts remain under
`assets/act3/source/finale_cast_v2_pixel/README.md`.

`mice.aseprite` is the editable 14×8 source. This replaces the old 9×6 marks
with enough pixels for the approved ears, snout, curved tail and little paws;
the body is still under half the adult protagonist's standing height.

Each colour has a four-frame 90ms walk and a six-beat gnaw lasting 760ms.
The walk alternates paws and tail; the gnaw lowers/raises the head, braces the
paws, and briefly reveals an incisor. The white mouse mirrors horizontally.
Both faces meet at the bite, on the stem lying along the cliff top, without
overlapping one another's bodies.

`scenes/props/sea/VineMouse.tscn` owns playback. Act3Beats stages the approach,
calls `gnaw()` on arrival, and leaves both loops running through the ending.
The gnawing's sound is the story beat's; the vine itself no longer trembles
(it is rooted in the rock and holds still, see Act3Beats._mice).

After saving Aseprite edits, run `python3 tools/export_finale_cast.py` to export
the atlas/JSON and rebuild `mice_frames.tres` from their source tags and timing.
Do not run the one-time `tools/build_finale_cast.lua` over later hand edits.

Test native pixels and playback with `tests/act3_finale_animation_test.tscn`;
the actual final-scene integration is covered by `tests/act3_tiger_test.tscn`.
