# Officer dialogue portraits

Generated with the built-in image_gen tool for the graffiti arrest in Act 2,
Level 14. Identity reference: `assets/props/school_wall/principal_walk.png`.
Style reference: `assets/characters/jamshid/portraits_v2/jamshid_determined.png`.
The original 2172×724 source has three equal 724px square panels in the order
alarmed, angry, stern. The source is preserved; no gameplay sprite was replaced.

The current officer has a full dark beard with subtle grey strands at the chin
and sideburns. The approved animation sources are in `animation/`, with a
matching prompt. The original moustache-only sheet remains as the design reference.

`tools/build_officer_portraits.gd` packs the authored 3×3 eye/mouth grids into
512×512 stills and nine-frame horizontal dialogue strips. Each emotion has
closed, parted, and open mouth poses combined with open, half-closed, and closed
eyes. It registers generated facial features to each emotion's closed-mouth
master; only the eye and mouth regions change, preserving the cap, uniform and
head position. Rebuild with:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/build_officer_portraits.gd
```

The exact generation prompt is in `prompt.txt`. Runtime faces are in
`../portraits/`. Per-line expressions are authored in
`resources/dialogue/act2_portrait_directions.json` and compiled by
`tools/compile_act2_script.py`; the school story selects those textures by state.

The strips are registered in `assets/portraits/loops/manifest.json`, using the
existing independent eye/mouth animation system. Mouths move only while text is
revealing, close during pauses and at the end of a line, and keep talking through
a blink. Eyes blink independently even while silent. The dialogue UI keeps the
same right-side placement as the officer's position in the scene.

Verify with `res://tests/officer_portraits_test.tscn` and
`res://tests/school_story_test.tscn`. Packed pose previews are saved to
`output/officer_portraits/`.
