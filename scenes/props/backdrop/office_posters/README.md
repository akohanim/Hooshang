# Act I office posters

17 decorative paper notices across the first ten rooms in actual play order:
`Level_0`–`Level_6`, then `Level_V1`–`Level_V3`. All nine approved designs appear;
the two banner designs have their own shuffle bag. Long slogans are reserved
for broad walls; narrow pillars reuse shorter designs rather than shrinking
letters. `scatter_seed` uses a private RNG, leaving gameplay randomness
alone. Reloading or dying does not reroll the layout.

`OfficePosters.tscn` owns the mounting rectangles in room-local pixels. They were
checked against full-room renders: plain wall panels, pillars, and the V1 notice
areas, clear of windows, platforms, lamps and exits. Change the rectangles here
if the architecture changes. The Act1World wrapper owns the installer, so LDtk
reimports preserve the dressing and Act II receives none.

`OfficePoster.tscn` is the reusable, collision-free decal. Paper edges, interior,
pictogram and lettering are all drawn at native game resolution. Each ink pixel is a whole game pixel, with
integer positioning and no font scaling or filtering. The 3x5 alphabet has a
four-pixel N to keep it distinct from M. NOW uses integer 2x ink pixels.

The first implementation reduced the complete concept artwork, which made
words unreadable; mipmaps improved aliasing but made the paper and text soft.
Do not restore either approach for the lettering. `MIN_WIDTH` prevents a long
slogan entering a narrow mount. The nine slogans are named in `office_poster.gd`.
Paper uses restrained gray/cream colors and `paper_brightness = 0.45` while
inheriting actual room lights. Four mounting styles vary independently of the
slogan: left/right folded notices with two fasteners, taped banners, and stapled
sheets. Folded corners change the actual paper silhouette and show a lighter
reverse face and crease; their one-pixel contact shadow follows the cut edge.
The Climb to Success notice uses fine-print rules like the user's reference.
Everything remains native pixel geometry, including paper and attachment details.
There is no light source or unshaded material. Multi-notice rooms
keep at least 160 game pixels of edge-to-edge clearance (half the viewport);
small rooms with limited mounting space get one notice instead of a cluster.

The approved source images are retained unchanged in
`assets/props/office_posters/source/`. They were generated with the built-in
ImageGen tool: worn ivory office paper, dark condensed type, thin double borders,
muted burgundy accents, pixel-art pictograms, pinned/taped corners, corporate
satire. The separate ninth design is “Think of the shareholders.”

Visual check:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tests/office_posters_preview.tscn
```

This captures all ten complete rooms under `output/office_posters/after/` at
three-times nearest upscale. It disables saving and removes story beats for
the capture only.
