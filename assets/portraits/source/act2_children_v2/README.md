# Act 2 child dialogue portraits

Generated with the built-in `image_gen` tool using the existing child identities and Act 1 adult portrait as references. Exact prompts are in `prompts.json`. Raw authored sheets are preserved beside this file.

The saved Hooshang source has measured row starts 0/280/544/808 rather than a regular grid. The packer intentionally reads those boundaries; it does not blindly slice quarters. The bottom row supplies eyelids only. Jamshid uses a regular 256px grid.

`tools/build_act2_child_portraits.gd` packs 512×512 stills and four-frame horizontal loops. It registers generated facial art against each emotion's resting portrait, copying only authored mouth regions for speech and eye regions for blinking. Hair, head, clothes and background remain the same pixels during animation. No gameplay character sheets are replaced.

Outputs: `assets/characters/hooshang_child/faces_v2/`, `assets/characters/jamshid/portraits_v2/`, and their matching files in `assets/portraits/loops/`. The existing dialogue system selects rest while silent, talk frames 1/2 during typewriting, and blink 3 independently. Speaker basenames preserve voice routing; the new distinct `jamshid_excited` face uses the existing joyful voice pool.

Build with the Godot editor closed:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/build_act2_child_portraits.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
```

Acting directions for later scenes are in `resources/dialogue/act2_portrait_directions.json`. Entries match both speaker and exact author text; `tools/compile_act2_script.py` rejects stale entries. This preserves the author's wording and scene order while adding a `face` field. The pond/campfire already had per-line acting directions and now use the new art.

`tests/act2_child_portraits_test.tscn -- --capture` checks all 12 expressions, pixel changes and stable hair, actual loop selection, voice identity, talking, pauses, sentence completion, independent blinking, and per-line expression coverage. Screenshots go to `output/act2_dialogue/`.
