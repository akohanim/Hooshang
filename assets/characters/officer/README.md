# Officer

The gameplay avatar now follows the bearded dialogue portraits: olive peaked
cap with brass badge and band, warm skin, thick brows, connected dark moustache
and full beard with grey chin/sideburn strands, cream shirt, dark tie, olive
uniform, brass epaulettes, pockets and belt buckle, and polished dark boots.
Colors are sampled from `portraits/officer_stern.png`.

## Editing gameplay art

Open `aseprite/officer_movement.aseprite` in Aseprite. It contains a transparent
32×48 canvas, five editable layers, and 16 frames in three animation tags:

- `idle`: four frames, including a blink.
- `walk`: eight frames with opposed arm/leg swings and a one-pixel body bounce.
- `talk`: four frames with a pointing gesture and alternating mouth poses.

After saving hand edits, run `python3 tools/import_officer_aseprite.py`. It exports
the saved frames and timing to `sprites/movement.png`, `sprites/movement.json`,
and `officer_frames.tres`. It does not redraw or replace hand edits.

`tools/build_officer_avatar.lua` is the initial native Aseprite authoring tool;
rerunning it replaces the source art. Ordinary edits use the export script only.

`scenes/characters/officer/Officer.tscn` instances the exported animation with
its feet at its origin. The graffiti scene walks him in along the pavement,
switches to his speaking gesture while his words reveal, rests between lines,
and turns him around for the escort out.

Room 14 fits the officer to twice Hooshang's visible idle silhouette height,
measuring opaque artwork rather than the different transparent sprite canvases.
The Aseprite source retains its full native 32×48 detail.

Portrait source art and eye/mouth animation documentation live in `source/`.
