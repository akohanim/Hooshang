# Act 2 quality standard

Working acceptance checklist, 2026-10-07. Act 1 is the reference, never an edit
target. The user confirmed that the castle contains the converted school-prison.

## Evidence behind the standard

Observed, input-directed play completed `Level_1` from its debug entrance to
`Level_2`, with no deaths or dash use. Its five ascending landings use bright
scaffolding edges against a dark wall; the open floor supports recovery; the
final chimney changes the movement phrase and reveals the lit exit. Posters, windows, structural beams and vents establish place without covering landings.

Observed play also completed `Level_8` through its real exit into `Level_9`.
The 40×24-cell music room places the exit's progress display in view from the
entrance. Notes 1–5 fold a vertical route back over itself; completing them
lights the onward platform and opens the door. A missed gap and a cloud hit
caused two deaths. Both returned to supported entry ground while retaining the
completed melody, light and open door. The final cloud can be watched from a
safe landing; a short jump and timed low dash passed beneath it. No wall grab
or climb input was used. Evidence: `act1_benchmark/observed_level8/`.

Transfer these observed behaviors to Act 2:

- Show the goal and its progress before a player commits to the challenge.
- Let completion visibly change the room, rather than merely adding a number.
- Preserve earned interaction progress on retry; replay movement, not bookkeeping.
- Put a stable waiting spot before a moving hazard and keep its cycle readable.
- Combine height/direction changes with a short final timing test, separated
  by landings where the player can stop. The music room's 6-cell vertical steps
  and 10-cell upper gap fit the adult dash; they are **not child geometry templates**.

Observed late-room play completed `Level_23` (Folded Stair) through its real
exit into `Level_24`, with two deaths. The first miss returned to the entrance;
a later shadow catch returned to the first internal checkpoint at (236,242).
The eight transfers form three phrases: two rising jumps left, four transfers
reversing right and crossing back left, then two final narrow catches after the
second checkpoint. The shadow/eruption sequence stayed enabled. Bright landing
edges remain distinct from the dark architectural background and lethal floor.
Evidence: `act1_benchmark/observed_level23/`.

The room's 24–40px intermediate landing widths and mostly 40px rises are adult
metrics, not child templates. Its stronger transfer is structural: vary direction
and landing demand, then bank a completed phrase before the next crux. A lemon
was visibly touched and trailed onto the upper balcony; this older capture run
has no banked-count telemetry, so the exact collection total is not asserted.
Earlier stale replay failures remain archived and do not describe this completed
observed run.

Observed optional-reward play completed `Level_3` through its actual exit into
`Level_4`, with zero deaths and one banked lemon retained across the transition.
The upper shelf sits above the visible exit; a diagonal dash extends the normal
scaffold route to the fruit, then a drop rejoins the exit without retracing the
ascent. Adult ledge assistance occurred, so this is a composition/reward
benchmark, not proof of a no-mantle child route. Evidence:
`act1_benchmark/observed_level3/`, including count/checkpoint telemetry and inputs.

## Checklist applied to every Act 2 room

- Purpose: name the room's movement idea, story/exploration role, and relation
  to the rooms before and after it. Remove redundant obstacle repetitions.
- Progression: introduce one idea with forgiving recovery; change direction,
  height or timing in its next use; combine only familiar ideas at a crux.
- Movement: use the real child profile (67.5px/s run cap, momentum retained in
  air, held/released jump gravity). Record a continuous route with no position
  injection. Do not tune the shared controller to rescue bad geometry.
- Readability: distinguish solid terrain, one-way scaffolding, water and hazards
  at 320×180. Show the next landing before commitment; keep its edge clear of
  pots, labels and effects. Show a safe waiting position before moving hazards.
- Fairness: sufficient body clearance, reliable takeoff/landing margins, no
  mandatory wall grab, blind lethal drop, single-pixel exit or inescapable pocket.
- Recovery: room arrival is safe, death returns to a supported position, and
  returning/backtracking cannot trigger a bounce between rooms. No checkpoint
  flags in the school-prison; keys never relocate its entry checkpoint.
- Pacing: separate demanding phrases with stable, quiet ground; give the castle
  approach a breather after the garden finale, not another difficulty spike.
- Exploration: optional lemons announce an intentional detour with a readable
  way back; missing a secret never blocks the required route.
- Place: architecture, scenery and ambient sound explain the location. Use the
  supplied castle sheets and existing Act 2 art; retain crisp edges and restrained
  watercolor shading. Preserve native character art and 8px alignment.
- Presentation: no labels overlapping players/keys, camera jumps, scenery gaps,
  repeated dialogue on ordinary retries, silent interactions that need feedback,
  or effects hiding hazards. Dialogue skipping reaches the same playable endpoint.
- Connectivity: enter and leave every required room, retry its hard section,
  and verify its intended return. Test both collected and uncollected key states.
- Evidence: label automated assertions, scripted input solutions, observed
  gameplay and static rendered inspections separately. Human feel remains open
  to the user's final playtest.

## Audit and preservation decisions

- `Act_2_Level_0`: retain the meadow, water and spring playground. Observed
  child movement clears the initial rise and spring launch; airborne framing
  currently gives weaker landing cues than Act 1. The redundant copied PlayerStart has been removed; the original spawn
  position is unchanged. Add clear resting/landing landmarks rather than replace the painting.
- `Act_2_Level_1`: retain the pond, fishing, night conversation and carpet
  departure. The observed swim approach exposed a dialogue landing fall through the pond;
  its scoped water staging now holds the swimmer safely. Observed skip and
  actual onward exit pass; disk-backed departure/retry/return checks pass.
- `Level_2`: the 1392×1088 draft stranded a missed spring route on a low floor.
  Replaced with a 960×320 dedicated carpet lesson: boarding bank, low arch,
  rising exit terrace and recoverable water. Observed flight and swimming
  recovery routes both reach the actual garden exit with zero deaths. Native
  child inputs also pass with land mantle disabled. Both optional lemon detours now have observed pickup/banking and actual
  garden-exit evidence: zero deaths, no climb or land mantle. The upper shelf
  is reached by flying above it and returning; the lower reward uses swimming. Later rooms retain local geometry;
  their LDtk world positions shift left to keep the shorter room adjacent.
- `Act_2_Level_3`: retain jump/dash introduction; inspect the first difficulty
  step after the opening and keep landing decoration out of the usable surface.
- `Act_2_Level_4`: retain spring steering; a two-cell wider third catch now
  passes without mantle. Vary presentation from room 0's springs.
- `Act_2_Level_5`: retain lower/upper choice. Both authored branches now pass
  continuous entrance-to-actual-exit checks, each banking its reward, with zero
  deaths and no climb/mantle. Observed misses verify entry retry and fruit
  persistence; an experimental drop between branches was unsuccessful.
- `Act_2_Level_6`: retain two carpet passages and their intermediate rest.
  Final thought column moved four cells earlier, leaving a clear dismount
  beyond its full horizontal sweep; scripted flight now passes.
- `Act_2_Level_7`: retain mixed spring/crumble/carpet sequence. The upper
  spring catch is two cells wider and passes without mantle; review retry length.
- `Act_2_Level_8`: retain safe-floor relief and wider landings.
- `Act_2_Level_9`: retain spring/dash relay. Two spring catches widened 16px
  toward takeoff after observed mantle-dependent catches. The full scripted
  route passes without climb/mantle and with zero deaths; raised relays use
  up-forward dash and held jump. All eleven required garden routes now pass their connected input-driven
  check; optional rewards and broader pacing remain under audit.
- `Act_2_Level_10`: retain leave-and-recatch carpet puzzle and safe post-flight rest.
- `Act_2_Level_11`: retain directional reversals; review camera visibility at ascent.
- `Act_2_Level_12`: retain short-hop variation; make low ceiling threat unambiguous.
- `Act_2_Level_13`: retain combined garden climax; remove premature finale cues
  and lead to the castle. The repeated entrance springs remain familiar takeoffs, with different
  subsequent transfer demands. Small landing platforms now omit pots; broad
  resting islands retain accents. Checkpoint pennants and premature completion
  text are removed. Titles have contrast shadows and clear the first platforms.
- `Prison_Hub`: retain four-key cage and selectable wings; establish the converted
  assembly hall, its entrance and rescue payoff. Preserve recent accessibility fixes.
- `Prison_R01–04`: timed cafeteria patrols, key, then short return; retain geometry
  that passes continuous play, improve patrol appearance and school identity.
- `Prison_G01–04`: library ascent, key and return. G02 now develops the first
  climb through a left/right shelf sequence to a raised archive entrance; G03
  has a reversible descending route. Forward and reverse no-assist loops pass.
  Preserve the filled exit recess and clear full-width apertures. Shortcut
  requirements now use nearby-player HUD text and small lock icons, clearing
  the archive scaffold and key.
- `Prison_B01–04`: flooded basement, surface transitions, key and return; preserve
  swim routes and add readable water depth/edges appropriate to the existing act.
- `Prison_Y01–04`: Y01 introduces wall jumps; Y02 now develops a distinct
  64px dash crossing with level takeoff/landing banks and a visible retry pit.
  Y03 descends to the key, Y04 returns to the hub. Forward and reverse loops
  pass without climbing or ledge assistance; observed misses respawn safely.

The initial audit found empty castle layers and a failing prison-layer contract.
The approach/gatehouse now use the installed masonry, and the contract is fixed:
all nested scenery is non-colliding; prison Collision remains its sole physics
authority. Castle tileset and connection checks pass.

## Milestone 1 design

Keep the existing garden finale. Add `Act_2_Level_14` (castle approach, 80×30
tiles) and `Act_2_Level_15` (school gatehouse, 60×30) before `Prison_Hub`.
The approach is a readable, forgiving stone stair and shallow water/bridge
crossing under the castle silhouette. The gatehouse provides quiet ground,
an optional upper lemon detour and a clear assembly-hall door. Warm exterior
light gives way to restrained indoor shadow. No new ability or progression item.
An explicit threshold transition connects the exterior to the interior rather
than panning across unrelated world-grid space. The prior prison remains intact
while this connected section establishes the visual and transition standard.
