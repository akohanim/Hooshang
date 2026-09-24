# Continuous Act 2 watercolor backdrop

`continuous_landscape.png` is one extended, sun-free painting. The left rolls
through dunes, the middle opens into a valley, and the right rises into mesas.
`single_sun.png` is the only solar disc. Both were produced with the built-in
imagegen tool using `../act2_sky/source/act2_sky_watercolor.jpg` as reference.

`scenes/props/backdrop/Act2Backdrop.tscn` displays these assets. Camera position
across the union of the three room bounds selects the view of the painting.
There is no repeat, mirror, room reset, or time-driven wrap. The entire image
covers the view even at the tall third room's extremes. The sun has a fixed anchor in
the painting and moves exactly with the landscape. It can naturally leave
the camera view; it is never clamped to the screen or moved on room entry. Normal CanvasModulate
still controls daylight and the encounter's sunset.

The older layer0–layer3 PNGs and their generator are retained as legacy source;
they are no longer referenced by the live backdrop.

Act 2 uses `pack_levels=false` in its LDtk import settings: embedding its rooms
in its own world prevents its `Level_2` from sharing/overwriting Act 1's
`ldtk/levels/Level_2.scn`. This does not rename or modify authored LDtk data.

## Generation prompts

Landscape (reference edit):
“Extend this watercolor game backdrop into a single very wide panoramic
landscape, 3:1. Preserve the hand-painted watercolor-on-paper style, watery
pigment pools, organic darker outlines, pale cyan sky, muted teal cloud banks,
peach ochre terracotta layered desert ridges. Genuinely new contours and cloud
formations across its full width; never copy/paste or mirror motifs. Left:
familiar low rolling desert. Middle: sweeping low valley and wispy separated
teal clouds. Right: taller sculptural terracotta mesas and hazy peaks. One
continuous painting, no panels or seams. Sky upper 65%, ridges lower 35%, pale
sand at bottom. Remove the sun entirely: zero suns, moons, or bright discs.
No buildings, vegetation, characters, text, borders, or new art style.”

Sun (reference extraction/recreation):
“Only the single pale cream watercolor sun disc as an isolated game sprite on
genuinely transparent background. One round disc centered with transparent
margin. Same pale buttery ivory, paper granulation, slightly irregular ochre
rim. Complete unobscured disc: no clouds, sky, desert, shadow, rays, halo, text,
or other objects. Flat watercolor style, quiet low contrast.”

## Verification

Run `tests/act2_parallax_test.tscn` headless to check all three rooms, coverage,
continuity, backtracking and the singleton sun. Run it with the Metal renderer
to save actual game captures to `output/act2_panorama/`.

The Jamshid dialogue drives `sun_descent`: an eight-second descent under the
sunset conversation, below the horizon as night arrives, and a three-second
rise alongside the dawn tint and fading stars. A horizon shader clips the
lower disc as it sets so it cannot paint over the distant terrain. This story
motion is independent of camera travel; normal play keeps a fixed anchor.
The end-to-end `act2_jamshid_encounter_test` verifies sunset, absence at night,
sunrise, and return to the daytime position.
