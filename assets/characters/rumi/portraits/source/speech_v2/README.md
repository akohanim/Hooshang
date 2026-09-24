# Rumi speech repair

Sorrowful (also used by wistful) and urgent previously had almost identical
mouths across their speech frames. Serene and warm_open already had visible
open-mouth drawings and are unchanged.

Built-in imagegen authored three new mouth poses per affected expression:
parted, open AH, and rounded OH. Exact prompts and generated source strips
are saved beside this file. Original still portraits remain unchanged.

`tools/build_rumi_speech.gd` extracts the authored mouth regions into the
original 256px portraits. Every pixel outside the mouth rectangle remains
identical across speech frames. The original sorrowful blink is retained
from `sorrowful_original_sheet.png` so rebuilding is reproducible.

Runtime sheets remain at `assets/portraits/loops/rumi_<state>_sheet.png`.
Frames: 0 original rest, 1 closed-mouth speech beat, 2 parted, 3 AH, 4 OH,
and 5 original blink for sorrowful. The existing dialogue controller cycles
2,3,2,1,4,2,3,1 while revealing text and restores frame 0 on pauses/end.
Authored roles prevent the legacy indexer from replacing these assignments.
No dialogue script or runtime controller change was needed.

Validation: `tests/rumi_speech_test.tscn` checks visible mouth-region changes
for all four Rumi states, every authored speech pose being reached, fixed
non-mouth pixels, frame bounds, and pause/end closure. `-- --capture`
renders four poses inside the actual dialogue banner to output/rumi_speech.
