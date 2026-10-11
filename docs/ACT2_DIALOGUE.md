# Act 2 child dialogue update

Child Hooshang and Jamshid now use matching 512×512 close-up portraits in the same banner, framing, speech animation, and blink system as Act 1. Each has six expressions: Hooshang neutral/happy/sad/surprised/annoyed/vulnerable; Jamshid friendly/joyful/worried/sad/determined/excited. Excited is now distinct artwork rather than a joyful alias.

All twelve portraits have authored rest, two speaking poses, and an independent blink. Registration keeps hair, clothes, head position, and background still while facial features animate. Voices retain their child-speaker identity. The original gameplay sprites remain intact.

The pond and campfire retain their existing acting directions. The wall, palace, reunion, chase, and farewell now read deliberate per-line expressions instead of defaulting Hooshang to neutral. The author's words and scene order are unchanged. Adult Hooshang and Rumi keep their existing portrait selection.

![Both children’s expressions](../output/act2_dialogue/emotions.png)

## Files and rebuilding

- Art: `assets/characters/hooshang_child/faces_v2/` and `assets/characters/jamshid/portraits_v2/`.
- Animation sheets and manifest: `assets/portraits/loops/`.
- Generated sources, exact prompts, and packing notes: `assets/portraits/source/act2_children_v2/README.md` and `prompts.json`. The built-in image-generation tool was used.
- Rebuild art: `tools/build_act2_child_portraits.gd`, then normal Godot import with the editor closed.
- Acting: `resources/dialogue/act2_portrait_directions.json`, compiled by `tools/compile_act2_script.py`. Speaker and exact text matching prevents stale directions from silently attaching to another line.

## Verification

`act2_child_portraits_test` checks all twelve expressions: visible dialogue text, square framing, displayed animation, child voice routing, changed pose pixels, unchanged hair, speaking, rest during a pause, rest after completion, independent blink, and available per-line expressions. Its rendered captures use actual authored lines.

Twelve related regression scenes pass: portrait animation, voice blips, dialogue placement, dialogue skip, dialogue scene controls, Act 2 pond encounter, Jamshid actor, Jamshid NPC, cell reunion, ending save, Act 2 progression, and staging skip. The NPC test now discovers the encounter room from `Act2Beats.room_name`, replacing its stale room-0 assumption. Results are in `output/act2_dialogue/regressions/` and `regressions_final/`; the latter contains the corrected NPC test run.

![Child Hooshang dialogue](../output/act2_dialogue/childhooshang_happy.png)

![Jamshid dialogue](../output/act2_dialogue/jamshid_worried.png)

Human review should judge expression intensity, likeness, and how the close-ups feel across an uninterrupted story playthrough. The automated checks establish correct rendering and behavior, not the emotional effect of a scene.
