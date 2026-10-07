> October 2026 insertion: **Level_19 — Against the Current** is a 2,696px
> leftward course with sixteen 120px right-running conveyor platforms (36px/s), five
> horizontal charge triggers, and two checkpoints. Darkshang rests as a large,
> floating, blinking storm cloud here and condenses into his existing humanoid form
> during charges and absorption. The supplied eight-frame transformation sheet
> plays during the final 0.55 seconds of the warning. After a missed charge he vanishes for the
> recovery interval, then reappears as a cloud at that charge’s launch position.
> While waiting and warning, the cloud stays fully visible at camera right.
> A brief inhale leads into smoothly blended, eye-aligned transformation poses.
> Independent rolling currents reshape its silhouette and shading while leaving
> its eyes readable. Waiting in this camera-anchored form cannot contact-kill.
> The same cloud/morph/return performance now applies to every charge room.
> Charge contact uses a swept 24×38px body at offset (0,−17), including legacy
> surges. Death/respawn and absorption timing remain unchanged.
> Crossing a charge trigger now starts a repeating sequence until death or room
> exit; later triggers take over its tuning. Recovery is multiplied by 0.5 at
> runtime: Level 18 = 0.55/0.50/0.475s; Level 19 = 0.6s; Levels 21–25 = 0.5s.
> The additional post-return pause is 0.175s (previously 0.35s); warning and
> approach durations remain unchanged. An upward dash clears the larger body.
> Levels 14–25 use the somber Shur Requiem reprise with continuous playback.
> Regression: `darkshang_shared_charge_art`, `darkshang_charge_balance`, and
> `darkshang_music` in addition to the original room tests.
> The previous Levels 19–25 are now **20–26**, including the finale. Older room
> numbers below describe the pre-insertion route. Existing room/entity IIDs and
> checkpoint IDs are preserved; schema-1 Act I saves migrate their room names.
> Play without saving: `res://tests/conveyor_charge_preview.tscn`.
> Regression: `res://tests/conveyor_charge_room_test.tscn`.
> The LDtk source holds the current authored geometry; do not rebuild older
> hand-edited rooms from the historical expansion recipes.

# Manually authored Darkshang powers

Historical implementation notes follow; the October 2026 summary above is the
current behavior where later revisions supersede these notes.

Open `ldtk/hooshang_act1.ldtk`. Three new entities are in the entity list.
They add no attacks until placed. Existing room layouts and attack recipes remain in place.

## Locked Charge

1. Put `DarkshangChargeTrigger` across the route. It needs an active Darkshang
   in the same room (the existing chase rooms already supply him).
2. Darkshang keeps following normally until the trigger fires. At activation,
   he holds his current pursuit position and locks the direction to the player's
   current position, including their Y coordinate. The warning shows that line;
   moving after the lock does not bend it. Jumping before the lock changes its angle.
3. Tune `WarningTime` (default .8 seconds), `Speed` (240 px/sec), `Distance`
   (240 px) and `RecoveryTime` (.7 seconds). Warning has a .15-second minimum.

There are no fixed charge launch points or directions. Old imported fields
`AimAtPlayer`, `Angle`, `UseLaunchOffset`, and `LaunchOffsetX/Y` remain readable
for compatibility but no longer control the attack, even in cached LDtk scenes.
Only timing, speed, range, trigger placement and repeat settings matter.

Darkshang holds still during the warning, charges on the locked straight line,
and stops at solid geometry or maximum distance. After recovery he repositions
behind the player's CURRENT position using `respawn_gap` along the room's route
(128px in the escape), fitted inside the room near its boundaries. He seeds a
new following trail there, rather than returning to the pre-charge trail or
waiting for the player to walk through another entrance threshold.

Only the moving charge is lethal during this move. Walls shield the player;
the hitbox sweeps the path even at high speed. Wall detection uses his smaller
geometry probe so a grounded charge does not begin embedded in the floor;
the full player-catching box is unchanged. Existing surges cannot interrupt it.
The warning line shows maximum travel; walls may stop him earlier.

## Shadow Eruption

1. Put `ShadowEruption` rectangles directly ABOVE the platforms you want to
   threaten. The rectangle's bottom must sit on the platform top; its entire
   rectangle is the damage area. Width changes coverage; height changes reach.
   Default height is one 8px cell. These entities add no solid collision.
2. Give related strips the same `EncounterID`, such as `A`.
3. Place `ShadowEruptionTrigger` across the player's route with that ID.
4. Set each strip's `Sequence`: 0 first, 1 next, etc. Equal numbers fire together.
   Start delay is Sequence × the trigger's `SequenceDelay` (default .35 seconds).
5. Each strip has its own `WarningTime` (.8 seconds) and `ActiveTime` (.55 seconds).
   Outlined cracks are safe. Raised dark spikes are lethal, then disappear.

Only strips in the trigger's own Entities layer are linked. Identical IDs in
other rooms are independent. Leave gaps between strips to author safe landings.

## Rearming and lifecycle

Both triggers default to `RepeatDelay = 0`: once per life. A positive value
allows another activation after that cooldown AND leaving/re-entering the box.
A player spawning inside a trigger must leave it first. Death and room departure
cancel pending eruptions and reset the triggers. Charge follows Darkshang's own
checkpoint/room-reset lifecycle. Dialogue freezes power timing; pausing freezes
it normally with the world. Triggers do not fire while player controls are locked.

For reliable imports, save/close LDtk before source edits and close the Godot
editor before a headless import. Reopen the project after import.

## Try and verify

Run `res://tests/darkshang_powers_gym.tscn` directly in Godot (F6). Walk right:
first trigger charges from his pursuit position; second fires three sequential floor strips.
Jump/dash to dodge. Death resets the exercise.

`Godot --headless --path . res://tests/darkshang_powers_test.tscn` checks locked
aim, warning safety, swept wall collision, recovery, checkpoint cancellation,
LDtk field conversion, packing, spawn-inside safety, linked timing and eruption
lethality/retraction. Definitions can be installed idempotently with
`python3 tools/ldtk_add_darkshang_powers.py --apply`.

## Placed progression: Levels 15–18

These placements follow the hand-edited LDtk geometry, not the older route
coordinates in `act1_expansion.json`. No terrain, ladder, platform, spawn, exit,
collectible or existing hazard was moved.

- **Level_15:** `L15_Intro`, one 24px strip on the first long landing, top y=96.
  The approach trigger at x=276 gives 1.1 seconds of warning and .55 seconds
  of danger. Both sides remain available for landing after a short jump.
- **Level_16:** `L16_Landing` threatens 16px of the lower platform at x=232;
  `L16_Climb` sequences two 16px strips on the y=168 platform, leaving a 16px
  safe gap. Warnings are 1.05/.95 seconds, active time .65, sequence spacing .45.
  The ladder itself and its dismount are not eruption volumes.
- **Level_17:** `L17_Roof` chases left across three separated roof sections,
  .35 seconds apart, with .75-second warnings and .8-second danger. A separate
  `L17_Drop` strip warns for .7 seconds on the lower landing. The existing
  pursuit stays enabled here; the crumbling platform and ladder stay untouched.
- **Level_18:** three one-shot charges, triggered at x=1256, 840 and 480.
  Each locks onto the live player from the live boss position. Speed rises 190 → 210 → 225 px/s;
  warning drops 1.0 → .9 → .85 seconds. Recovery is 1.1 → 1.0 → .95 seconds.
  Follow delay is 3.6 seconds; automatic surges are effectively disabled
  (`surge_interval=999`) so the placed charges set the attack rhythm.

All coordinates above are room-local pixels. Each attempt resets on death.
The previous entrance-side charge trigger in Level_18 was reused and moved
onto the route; it was not left as a fourth entrance ambush.

`tools/place_darkshang_15_18.py --apply` reapplies these power placements while
asserting that every other source value is unchanged. It replaces powers in
these four rooms, so edit its placement data if you want reruns to retain new
manual power tweaks. `tests/darkshang_15_18_test.tscn` checks imported support,
live-position aiming, actual trigger activation, linkage and retry reset.
`tests/darkshang_eruption_dodge_test.tscn` tests a real-controller jump response
against an uninterrupted-run control on the introductory strip and roof wave,
and confirms that the upper Level_16 landing has a usable refuge between strips.

## Baseline pursuit throughout the escape

Levels 15–25 all enable the same physical Darkshang actor's baseline follow.
The normal follow delay is 3.2 seconds (Level_18 retains 3.6 seconds). Placed
charges and eruptions supplement this pursuit. Existing entrance/respawn grace
keeps him offscreen until the player commits 24px (three tiles) along the route; Level_25
continues pursuit into the cubicle, where the existing ending line stops and
dissolves him. Terrain, existing traversal/puzzle modes, and power placements
are unchanged.

`Act1ChasePacing` reads the four chase settings from the recipe JSON at runtime,
so a chase-only configuration edit takes effect on a fresh game launch without
an LDtk re-import. `tests/darkshang_baseline_test.tscn` verifies actor binding,
body visibility, movement and retry arming across the escape, plus pursuit,
death/retry, and the final dissolve inside Level_25.


## Entrance always precedes powers

In Levels 15–25 the player must advance 24px along the route. Darkshang then
appears inside the room near its entrance, rather than turning visible offscreen
at the full chase gap. The pursuit tape is seeded from his actual entry point,
so his body stays in the room and retains the configured follow delay.

A further .35-second entrance beat must complete before a charge, eruption or
legacy surge can begin. Standing still or backing up never releases entry.
Death and room entry reset the rule. Both eruption triggers and direct strip
activation check the same physical actor, so no invisible boss can cast them.
The guarantee is tested across all ten rooms in `darkshang_power_entry_test`.

Eruptions use the original outlined crack warnings and raised dark spikes.
The entrance rule, placements, warning durations and damage volumes are unchanged.


`tests/darkshang_dynamic_charge_test.tscn` checks different target heights,
locked trajectories after the player moves, old fixed fields being ignored,
return placement from the player's end-of-recovery position, reseeding without
snapping onto an old trail, cancellation on respawn, and grounded charges.

## Level_19 ladder-bottom series

A 32×16 `ShadowEruptionTrigger` centered at (724, 352), the bottom of the
ladder, starts encounter `L19_LadderBottom`. It respects the same physical
Darkshang entrance gate as all other powers. The four manually placed strips
remain at (604,332), (532,356), (460,324), and (116,324), firing right to left.
Their Sequence values are 0, 1, 2, and 7 with SequenceDelay 1 second: each has
1.5 seconds of crack warning and .8 seconds of active spikes, so lethal phases
begin 1.5, 2.5, 3.5, and 8.5 seconds after activation. The longer final gap
allows travel toward the distant last strip. This is one series per life;
death resets the trigger and all strips. Terrain and existing entity positions
are unchanged.

`tools/place_darkshang_level19.py --apply` configures those existing strips and
adds the trigger, asserting the rest of the source is unchanged. Update its
placement guard before reapplying after manual strip moves. The imported
encounter, entrance gate, warning/active timing, once-per-life behavior, and
death reset are covered by `tests/darkshang_level19_test.tscn`.

## Levels 20–24 mixed encounters

Each room has two player-aimed charge triggers and two once-per-life eruption
triggers. All charges start from Darkshang's current pursuit position, lock
onto the player's position, and return behind the player's current position
afterward. The standard entrance gate applies to every power.

- Level_20: charges on entry and past the middle checkpoint; single eruptions
  on the first small landing and the last small landing.
- Level_21: charges between traversal sections; two staggered strips on each
  conveyor, leaving gaps to dodge into. The strips sit on the belts' actual
  surfaces, above the underlying terrain.
- Level_22: charges at the lower approach and middle climb; one lower-platform
  eruption, then a delayed pair across the upper landings.
- Level_23: charges before the first crumbling-platform run and around the
  middle climb; eruptions on the far edges of the two solid checkpoint ledges.
  Checkpoint standing positions remain clear. No strips are attached to
  crumbling platforms.
- Level_24: slightly faster charges alternate with a two-platform eruption
  sequence and a final single strip before the exit approach.

Charge warnings range from .9–1.05 seconds, speeds from 200–225px/s, and
recovery is 1 second. Eruption warnings range from .95–1.15 seconds with .65
seconds of active spikes. All entities remain editable in LDtk. Terrain,
existing props, checkpoints, and exits are unchanged.

`tools/place_darkshang_20_24.py --apply` installs these named encounters with
stable IDs; rerunning reapplies their authored settings while preserving
unrelated entities. `tests/darkshang_20_24_test.tscn` checks all imported strips'
support and clearance, checkpoint safety, trigger activation, encounter links,
charge aiming/travel, and reset behavior.

## Player-responsive attacks

Charges now travel the larger of twice the authored `Distance` or the distance
to the locked player position plus 160px. The entire straight trajectory is
shown during the warning. Darkshang phases through terrain during this attack,
so a platform cannot cut the charge short. A swept contact check catches the
player even during a large movement step and starts the existing consumption
animation, ending in death. A miss still recovers behind the player's current
position. The target never follows the player after lock-in.

Each eruption samples the player's current horizontal position when its own
warning begins, including delayed strips later in a sequence. It slides up to
64px from its authored center along the same continuous platform, requiring
solid support under its full width and clear space above. It preserves checkpoint
refuges and avoids stacking on another scheduled or active strip. The warning then
locks the position for a fair dodge; death, room changes and expiry restore the
authored center. Existing encounter links, sequence timing, vertical placement,
and spike art still define each room's strategy. `targeting_radius` on the
runtime strip controls this radius (zero disables targeting).

`darkshang_targeted_eruption_test` covers delayed targeting, different player
positions, fixed warnings, platform-edge limits, checkpoint clearance and reset.
`darkshang_dynamic_charge_test` also covers consuming a player beyond the old
range and the actual ingestion animation completing in death.

## Horizontal charge staging

Darkshang eases to the camera's right side over .45 seconds while matching the
player's height. During the full authored pre-charge warning, he continues
tracking that height exactly, with no vertical offset or bob. The warning line
is horizontal. When the warning ends, he locks the latest height and charges
straight left; later jumps or falls cannot steer the charge. Reach still extends
at least 160px beyond the player's locked horizontal position.

After a miss, recovery eases him behind the player's current position. Pursuit
is seeded from that return point to avoid snapping to the old trail. Contact
still consumes the player, and the entrance gate remains unchanged.
`darkshang_smooth_charge_test` checks visible right-side staging, height tracking,
horizontal lock, and smooth return. `darkshang_dynamic_charge_test` checks
multiple player heights, post-lock dodging, extended reach, consumption and reset.
