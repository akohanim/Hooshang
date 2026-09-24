> Historical design notes below. The current implementation is described in [DARKSHANG_ENCOUNTERS.md](DARKSHANG_ENCOUNTERS.md) and [LADDER_ROOMS.md](LADDER_ROOMS.md); these supersede the old phase locks, seal puzzles, appearance progression, lighting and attack limits.

# Act I: learning to move with the darkness

Implemented September 10, 2026. Scope: the active route from Level_V10 through Level_25. Existing shelved numbered rooms 7–13 remain shelved; no room identifiers, save identities, story lines, or finale destination were changed.

15 rooms fundamentally rebuilt; Level_14 moderately changed; Level_25 deliberately preserved. The former repeated chase courses now alternate observation, circuits, attack manipulation, temporary architecture and quiet traversal. There is no boss health, shooting phase or damage race.

## Reading the encounters

A pause symbol and filling ring mean **stand and observe**. Circuit cables physically connect their terminals in order; stand on a terminal for 0.35 seconds to commit it. Crossing a terminal without stopping does not accidentally commit it. Hollow and filled sockets distinguish absence and presence. An X is a shadow-sensitive seal. Hatched danger is a warning; dense darkness is the active hazard. Shutters remain visible until their collision actually opens.

Darkshang waits for 16 pixels of forward commitment. His arrival gathers for 1.4 seconds; his presence lasts 7–8 seconds, his departure 1.2 seconds, then the room gets 5–8 seconds of quiet. Entire intervening rooms provide longer relief, depending on player pace. He uses at most **one attack per manifestation cycle**. A pulse or mark warns for 1.4 seconds; the low sweep warns for 1.8 seconds. Marks lock their position at the warning. Pulses travel at 62 pixels/second. Solved attack rooms stay quiet.

All relief remains inside the dark office: dim blue light, industrial silhouettes and restrained ambience. The former sunny recovery rooms were removed. Quiet reduces music volume and fog pressure; it does not change the setting into a different Act.

## Level-by-level direction

### Level_V10 — The Other Shift · rebuilt

**Before:** seven relatively conventional platforms with moving thoughts; traversal did not establish a distinct dramatic question. **Now:** a long sightline across staggered scaffold bays leads to an observation station. Holding still while the watcher is present opens the route. The player must first notice that fleeing is not the solution.

**Darkshang:** manifestation 1, small, recognizably human, hunched and slightly out of time with the room. No attacks. He gathers across the gap, watches, and dissolves when the observation completes. The remaining bays are safe from him and introduce the dark architectural language. The visible ring teaches the final sequence's stopping action. Low execution difficulty; no checkpoint.

### Level_V11 — Trace the Circuit · rebuilt

**Before:** a chain of crumbling panels made urgency largely a matter of continuing forward. **Now:** follow an exposed cable across three terminals, including a deliberate backtrack past a terminal that must be crossed without activating it. The shutter makes successful sequencing necessary.

**Darkshang:** absent throughout. Quiet fixtures and stable decks give the player time to trace the wiring. The industrial sockets foreshadow later state-dependent mechanisms. This introduces observation, route planning and controlled landings without a timer or punishment for a wrong guess. No checkpoint.

### Level_V12 — Negative Space · rebuilt and shortened vertically

**Before:** fourteen ascending platforms repeated a climb across a 384-pixel room. **Now:** a seven-landing, 256-pixel switchback. Activate the lower socket in absence and the upper socket during presence. A full-height shadow curtain and complementary temporary beams make the timing of a crossing meaningful. Ghost outlines show where a beam will exist.

**Darkshang:** manifestation 1 watches without attacking. Gathering announces the dark route; departure announces its removal. Quiet makes the complementary beam available. This is the first sustained combination of phase observation, a return crossing and vertical precision.

**Checkpoint:** the single dedicated checkpoint in this pass, on the landing at local (64,120), after the lower circuit and crossings. It preserves earned puzzle progress on death. The upper execution can be retried without repeating the entire lower solution.

### Level_V13 — Between the Hands · rebuilt

**Before:** another broad forward route with paired thought motion. **Now:** a circuit requiring a cross-room return, with opposing DarkThought and LightThought motion covering the important transfer. Their phases differ by half a cycle. Read the cable, watch a complete thought cycle, then execute the crossing; an optional lemon rewards additional exposure.

**Darkshang:** absent. The thoughts carry the pressure instead. There is no attacking shadow waiting behind the player, so observing their rhythm is valid. This is the hardest preparatory circuit and the principal reusable-thought timing room. No checkpoint; failure restarts this room, not the preceding puzzles.

### Level_V14 — Do Not Follow · rebuilt

**Before:** a small traversal section with another collapsing platform and roaming hazard. **Now:** a compact pause station between substantial landings. Stand still for 2.5 seconds and let the shadow leave instead of pursuing him.

**Darkshang:** manifestation 1, a slightly altered human outline; no attack. He gathers, watches, then fades after the stillness condition. Stable geometry and the short route deliberately lower pressure immediately before the story reveal. This is a breather and thematic rehearsal, not a difficulty peak. No checkpoint.

### Level_14 — the Darkshang encounter · moderately changed

**Before:** the scripted confrontation's surge hazard added immediate chase pressure before the new threat had been taught. **Now:** retained the authored reveal space, dialogue, entrance reversal and departure route; removed its SurgePoint and reduced the original story actor to a human-scale silhouette.

**Darkshang:** the original animated actor still performs the reveal and brief follow. He does not fire projectiles here. The encounter establishes recognition and unease; Level_15 introduces his new reach. Rumi and Hooshang's dialogue remains intact. No added checkpoint.

### Level_15 — Borrowed Reach · rebuilt

**Before:** a seven-platform run course with continuous pursuit. **Now:** bait a low pulse toward a distant seal, then take the upper scaffold route. Running straight to the exit cannot solve the shutter. The player must align Darkshang's reach with an object that Hooshang cannot activate.

**Darkshang:** manifestation 2, broader and taller, with drifting fog, a reaching arm and a body that compresses into mist on departure. Only a slow horizontal shadow pulse. Its hatched wind-up and fixed travel band teach the attack safely; upper decks provide separation. Breaking the seal makes him fade, and the exit opens when the fade completes. Level_16 then provides a whole quiet room. First major attack-puzzle increase; no checkpoint.

### Level_16 — What the Dark Left · rebuilt

**Before:** an avalanche-style chain of crumbling platforms prolonged the same pressure. **Now:** stable alternating-height scaffolds, a cable circuit requiring a return crossing, and an optional lemon. The solution remains deliberate but has no pursuing timer.

**Darkshang:** absent throughout. Fog pressure and ambience fall after the previous seal breaks. Dark walls and cool fixture pools preserve the psychological space. The circuit reinforces selective activation before marks arrive. Execution is intentionally easier than Level_15; no checkpoint.

### Level_17 — Choose the Wound · rebuilt

**Before:** a service-spine traversal with another roaming thought. **Now:** stand on the seal's landing long enough to invite a mark, then retreat to the raised scaffold before it erupts. The mark opens the shutter only if the player deliberately placed it on the seal.

**Darkshang:** manifestation 3, larger, partly transparent, with sheared duplicate contours and intermittent fragments. The arm/body tell now precedes a locked environmental mark rather than a travelling pulse. Its eruption occupies one readable area. He fragments outward and fades after the seal breaks; Level_18 follows with no attack. First explicit manipulation of target placement; no checkpoint.

### Level_18 — Afterimage · rebuilt

**Before:** a bright winter-garden recovery room broke the dark sequence's identity. **Now:** a short, dim observation chamber with a pause ring and generous stable landings. It asks for stillness without a hidden punishment.

**Darkshang:** absent throughout. The lighting eases slightly, but the walls, voids and steel remain dark. This is the clearest uninterrupted relief beat after learning marks. The familiar hollow ring leads into the presence sockets next door. Deliberately low difficulty; no checkpoint.

### Level_19 — A Route That Wants Him · rebuilt

**Before:** a small warm recovery course without a consequential environmental state. **Now:** bank an absence socket, wait for the room to gather darkness, cross the shadow curtain, and reach the presence socket. Temporary scaffold bridges change with the cycle. A curtain never materializes collision inside the player.

**Darkshang:** manifestation 4, roughly twice human scale, heavy shoulders, fragmented limbs and a wider fog field. No projectile is needed: he controls the architecture. Arrival creates a route; disappearance removes that route and restores the quiet alternative. Recognizing the phase is more important than speed. First room where wanting his return is part of the solution; no checkpoint.

### Level_20 — Teach the Room to Break · rebuilt

**Before:** a mushroom/grey-thought passage gave the player a temporary immunity shortcut. **Now:** a two-stage attack circuit. Bait a mark on the upper receiver, then use a later pulse at the lower receiver. Each receiver requires the correct attack, and only the current one can advance the mechanism. Retreat and change elevation between stages.

**Darkshang:** manifestation 4, unstable and fog-bound. Mark and pulse alternate across returns, never simultaneously. The first broken receiver reveals the second; the later receiver requires a different spatial answer. After both break he stretches down into the room and dissipates. Level_21 is quiet. This is the largest attack-reasoning increase before the finale; no internal checkpoint because the room is compact and the two stages themselves are the challenge.

### Level_21 — The Shape of Absence · rebuilt

**Before:** another thought-lined four-platform chase route. **Now:** a circuit that returns to the entrance landing for its final activation. Route memory and restrained terminal contact replace forward flight. The exit remains reachable once the circuit is complete.

**Darkshang:** absent throughout. Stable scaffolds and quieter ambience allow decompression after the two-stage attack puzzle. The cables and empty shadow sockets preserve anticipation without secretly restarting pursuit. Easier execution, with a final backtracking decision. No checkpoint.

### Level_22 — Wait for the Floor · rebuilt

**Before:** another last-leap/crumbling-platform obstacle. **Now:** alternate between an absent-state socket and a present-state socket while the curtain and ghost beams cycle. The player must read the room even though there is no solid figure to watch.

**Darkshang:** manifestation 4's environmental residue, with the body deliberately absent. Lighting and architecture announce the pressure cycle. There are no projectiles. A route appearing from an apparently empty room foreshadows the building-sized body in Level_23. Difficulty comes from predicting a crossing window, not shortening the landing. No checkpoint.

### Level_23 — The Whole Building · rebuilt

**Before:** a short “Daybreak” route under the same small pursuing silhouette. **Now:** bait the upper seal's mark, return to an elevated refuge, survive the next low sweep, wait for the exit shutter to open, then cross the collapsing lower landing. A presence-only intermediate beam affects the return to high ground.

**Darkshang:** manifestation 5, a separately constructed enormous upper body behind the level, broad shoulders, long arms, fragmented fog bands and small warning eye cracks. This is not a scaled-up sprite. Mark, sweep and pulse are available across successive cycles; one occurs per cycle. The fixed sweep threatens y144–168, leaving the upper decks visibly safe. The seal alone cannot finish the room: surviving the sweep is also required.

His departure dissolves the torso into the building's dark bands. Solving stops subsequent returns. The architecture's final crumble creates a short execution finish after the observation and baiting sequence. This is the difficulty peak. No checkpoint: each attempt begins in this compact room, and the crumble is readable and short.

### Level_24 — You Can Stop · rebuilt

**Before:** a familiar corridor with low mechanical consequence immediately before home. **Now:** bait the known mark on the upper seal, let the enormous figure dissolve, then stand quietly at the lower observation station during absence. Moving onto the station while he is still present does not satisfy the ending. The final raised exit requires a planned takeoff.

**Darkshang:** manifestation 5 with a different fragmentation phase; mark and low sweep alternate across returns. The giant threatens the room but cannot be defeated by damage. The player now knows how to manipulate a mark, seek elevation and recognize the departure. Once the stillness completes, he stays gone. The shutter leads directly to the original cubicle.

The last answer is restraint rather than a faster chase. No checkpoint; ordinary room arrival prevents replaying Level_23.

### Level_25 — original cubicle · preserved

The cubicle room data is unchanged from the pre-redesign version, including its established Level_0 likeness. Hooshang and Rumi's final dialogue and the existing destination remain intact. The old chase actor is hidden here because the colossal presence has already dissolved. No new hazard, puzzle or checkpoint interrupts the ending.

## Reusable implementation

- `scenes/props/darkness/darkness_room.gd`: deterministic phase lifecycle, entry commitment, shadow-sensitive seals, two-stage receivers, stillness stations, wired circuits, phase sockets, full-height shutters, temporary 8px scaffold bridges, pulse/mark/sweep warnings and damage, death reset and checkpoint banking.
- `scenes/props/darkness/darkness_manifestation.gd`: five native-resolution silhouettes, variant timing, evolving arrival/departure treatment, fog and architectural-scale final body. Visual size never changes the attack collider.
- `scripts/act1_chase_pacing.gd`: room director. Prevents the old delayed-echo chaser from killing the player while a new room asks them to stop. Original story actor remains in Level_14.
- `resources/levels/act1_expansion.json`: authored geometry, state puzzle and attack configuration. `tools/build_act1_expansion.py --install` rebuilds only targeted LDtk rooms, with editors closed.
- Existing thought motion, crumble animations, player physics, fixtures, brick/stone/scaffold tiles and dialogue systems remain in use. The new short synthesized breath/knock supports phase and attack cues without a fireball sound.

All 662 scaffold cells in the audited edited scope have no scaffold cell immediately above/below them. Permanent and temporary decks are 8px deep. Brick/stone foundations remain substantial; masonry sockets attach at beam ends rather than thickening the steel. Cables, ghost beam outlines, warning hatching and distinct shutters improve structural and collision readability.

## Verification and limits

The acceptance scenes separate three kinds of evidence:

1. `darkness_geometry_test.tscn`: real movement/collision tests for every route leg in all 15 rebuilt rooms; gates disabled solely for traversal isolation.
2. `darkness_contract_test.tscn`: actual warning, locked target, attack/receiver, state socket, upper sweep refuge, single-attack cadence, persistent respite and retry behavior.
3. `darkness_playthrough_test.tscn`: complete room puzzles and exits through real movement input, with no mid-room teleports or gate bypasses. Retries start at the entrance. A checked-in fixture keeps runs independent of generated output folders.

All three acceptance scenes pass: every route leg, the encounter contracts, and all 15 complete room puzzles/exits.

`act1_finale_test.tscn` also walks the Level_14 approach using movement input, runs both preserved conversations through the real dialogue system and checks the existing handoff. Actual rendered 320×180 viewport captures were reviewed for every rebuilt room, including the giant's layering and the warning/readability pass.

Iteration fixed a hidden shadow behind an opaque wall, a self-intersecting dissolve polygon, puzzle indicators occluding the player, an exit shutter becoming visually absent before collision opened, short-room takeoff geometry, a temporary bridge transfer and the collapse test pilot's handling of JSON numeric indices. The final collapse requires a prompt hop, not walking the length of an already crumbling panel.

The required 34-test regression run returned **24 passes and the same 10 failures/timeouts as the pre-redesign baseline**, with no changed exit statuses. Existing failures: backtrack, Level_v6 return race, intro, death, slide, conveyor, save, jump tutorial, chimney and pause. Logs also contain pre-existing missing/shelved-room warnings and teardown resource-leak warnings. This pass does not claim those unrelated failures are repaired.

**Remaining qualitative risk:** these are automated controller playthroughs and rendered-view inspection, not a fresh player's blind playtest. V16 and V21 deliberately reuse the circuit vocabulary and remain less novel than the attack/state rooms. Their role is relief; whether their clue readability and length land well needs human play. The 5–8 second within-room absences are short breaths; the longer emotional relief comes from whole quiet rooms. No claim is made that a new player will take an exact number of minutes between manifestations.
