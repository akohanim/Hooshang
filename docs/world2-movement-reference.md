# World 2 movement reference

The user-linked game is **Super Mario World (SNES)**, not Super Mario Bros. Wonder.
This implementation targets the former's movement, exclusively in childhood Iran.

## Evidence

Downloaded the [user-supplied US ROM](https://archive.org/details/super-mario-world-usa_202406)
and ran it through libretro/snes9x2005, built locally at commit
`a79dfe9047e7fec58808aefe48ad2bf499c7af11`. ROM SHA-256:
`0838e531fe22c077528febe14cb3ff7c492f1f5fa8de354192bdff7137c27f5b`.
Cross-checked the jump/gravity tables at CPU addresses `$00D2BD` and `$00D7A5`
against [SMWDisX bank 00](https://github.com/IsoFrieze/SMWDisX/blob/master/bank_00.asm).
No Nintendo executable code, audio, ROM or save state is shipped in Hooshang.
The subsequent, explicitly requested sprite adaptation is described below.

`tools/measure_smw_movement.py` boots through real menu inputs, drives joypad input,
and samples player position, velocity and state from WRAM every emulated frame.
Vertical trials pin X to an unobstructed point while preserving horizontal speed,
so a wall, enemy or changed floor height cannot contaminate the jump measurement.
Horizontal traces use normal position integration. These are controlled locomotion
experiments, not a full-game playthrough, and do not cover cape flight, Yoshi,
water, slopes, P-speed or every enemy interaction.

Reproduce using a supplied ROM and compiled libretro core:

```sh
python3 tools/measure_smw_movement.py --rom /path/to/game.sfc \
  --core /path/to/snes9x2005_libretro.dylib --output /tmp/smw-measurements
```

The checked-in telemetry is `tests/fixtures/smw_movement_reference.json`.
Its distances are SNES pixels. The adaptation uses half-distance units to match
Hooshang's 8px tiles against the reference's 16px terrain units, retaining frame
timing on Hooshang's 60 Hz physics clock.

## What changed

The original Hooshang jump sustains a fixed upward velocity while held, then
coasts. The reference instead changes vertical velocity continuously: holding
jump uses a lower gravity; releasing it doubles gravity. That is why simply
slowing every number did not reproduce the reference's rounded jump.

Measured standing jumps range from 33 SNES pixels/28 frames for a one-frame tap
to 64 pixels/54 frames held. At half scale, the new Hooshang controller measures
16.7px/29 frames and 32.2px/54 frames respectively. A running held jump measured
81 SNES pixels/61 frames; Hooshang measures 40.8px/62 frames. Small differences
come from integer SNES positions versus Godot's continuous collision coordinates
and their first/last airborne tick accounting.

Horizontal motion now builds gradually, coasts on release on the ground, and
brakes more strongly when reversing. Neutral air input retains horizontal speed.
The new run cap is 67.5px/s, close to the previous 66.24px/s World 2 cap; the
large feel difference is acceleration and momentum, not a faster top speed.
Running also increases jump launch speed modestly, matching the measured
standing/running distinction.

Existing directional controls select the normal-run cap automatically. This is
an adaptation, not a button-for-button emulator: no walk/run button or P-meter
has been added. Dash, swimming and spring interactions remain Hooshang systems.
Spring trajectories retain their authored reach, and carpet boarding absorbs
matching forward speed before the carpet supplies its separate carry motion.
World 2 rugs wait for central footing before departing; a tight geometric support
check bridges the one-frame floor-cache lag when vertical steering stops.
Ordinary jumps intentionally gain horizontal reach compared with the previous
Celeste-style arc. No air twirl or new collectible behavior is included.

## Isolation and verification

The shared player scene defaults to the original model. Only Act2Beats enables
the new branch on its own player instance. `world_movement_isolation_test`
compares World 1 and World 3 settings before and after loading World 2.
`childhood_tempo_test` tests the measured arc family, braking and air momentum;
`act2_routes_test` drives real inputs through the authored routes without
mid-route position or velocity writes. Its driver now anticipates stopping
distance and verifies actual support before treating a carpet as boarded.

The final checks passed for movement isolation, measured jump arcs, smoke physics,
world bounds, swimming, carpet behavior/return/obstacles, side springs, World 2
expansion and progression. The full route run exposed two stale input recipes;
Levels 3 and 11 both passed on targeted reruns after choosing a full jump hold
and an up-forward dash respectively. Level 10 also passed in a rendered run,
including all three same-carpet recatches. No level geometry was changed for
this movement adaptation.

## Small Mario sprite adaptation

The user selected Small Mario and requested the same facial/body structure,
with superficial clothing and hair changes. The earlier independently drawn
interpretations were rejected. The current child source therefore follows the
actual Small Mario pose geometry, recoloured for Hooshang, rather than claiming
an original silhouette or an eight-frame animation cycle.

Captured 4bpp OBJ tiles from the running SNES core, cross-checked against the
visible framebuffer and the pose register. Normal directional walking alternates
poses 0 and 1 every six 60Hz ticks at its speed cap. Held-button running shortens
that delay to three ticks before P-speed; Hooshang's existing movement speed
modulates its two-frame clip. A real standing jump selects pose 11 while rising
and 36 on descent. The ROM's swimming sequence is 22/26/26/24; climbing mirrors
the back-facing pose rather than flashing between front and back views.

Additional poses were inspected with a temporary research-only ROM modification
that disables writes to the pose register, allowing the game's own graphics
lookup to render a selected pose. This patch is not included in Hooshang. The
original ROM and unmodified reference captures remain outside runtime assets.
The edited Aseprite now contains 63 frames and 24 gameplay tags. The 20-pixel visible
standing body is authored as 2x2 source clusters, rendered at exactly 0.5 scale
with a thin contour. It is slightly taller than the old 15px art; the collision
body and World 1/3 visuals are untouched. Hooshang-specific dash, mantle and
rest poses are adaptations, not claims that SMW contains those same abilities.


## Completed child animation pack

A fresh run of the local SNES reference confirms normal walking alternates poses
0/1 at six ticks per pose after acceleration; fast running reduces that to three
ticks and ultimately selects 4/5. A standing held jump presents pose 11 for 27
ticks and pose 36 for 26 before landing. Reversal shows pose 13 for seven ticks.
Underwater verification uses the actual water-level flag (`$85`) as well as the
player water flag (`$75`): repeated strokes show 22 for twelve ticks, 24 for four,
and 26 for eight. The animation table at `DATA_00D980` is 16/1A/1A/18 in hex,
indexed by the descending timer divided by four. A swim-input press sets bit 4
of that timer. These are reference measurements, not Hooshang physics constants.

The saved Aseprite now has 63 frames/24 tags. The approved child design, adult-matched
clothes, hair fill and single-source-pixel contour are retained. Run, sprint,
skid and swim use the measured poses/rhythm. Idle blinking, launch/landing
compression, dash lean, wall-jump release and bank/ledge transitions are adaptations
for Hooshang's move set. The controller's existing timers select takeoff, rise,
apex, fall, land and recovery; the child resource now supplies those clips.
The child-only ground selector adds sprint/braking and a visual crouch. Neither
collision nor movement constants changed; Worlds 1/3 retain their adult visuals.

Nintendo's [original SMW manual](https://www.nintendo.co.jp/clvs/manuals/common/pdf/CLV-P-SAAAE.pdf)
provides the reference action vocabulary. The ROM and emulator inspection files
remain outside shipped assets. Preview: `output/child_animation_pack/animations.gif`.


### Swim recapture correction

A second controlled capture tested a single stroke, repeated strokes, no stroke,
and left/up/down travel. All directions keep the head upright; horizontal travel
only mirrors the sprite. A single press produces 24 for 4 ticks, 26 for 8 ticks,
then holds 22 indefinitely. With a press every 24 ticks, the glide holds for 12.
Hooshang now starts on the pull rather than delaying it behind the glide and uses
22 as the neutral pose. The previous runtime rotation was incorrect for these
already side-view poses; it remains enabled only for the adult library.

The active Hooshang cycle still repeats while steering, matching his existing
swim controls. This is an animation adaptation; no swimming physics or input
bindings were changed. Comparison GIF: `output/child_animation_pack/swim_corrected.gif`.
