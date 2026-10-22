# Chase movement and ditch recovery

The Rocks screenshot exposed a 24px-wide, 40px-deep pocket. The Wood had a
matching 32px-deep pocket. Falling into either dropped Hooshang below the
tiger's recorded route, so its jaws stayed overhead indefinitely. The narrow
walls also made the escape awkward under chase pressure.

Both authored profiles now retain an 8px depression instead. `SeaRoom` repairs
the older packed grids before building physics, reconnecting the visible Grass
atlas around the filled cells as well. This lets existing imports pick up the
fix immediately; no running editor/LDtk session is closed or overwritten.
The correction is limited to these two rooms and is idempotent. A missed jump
can be recovered with an ordinary jump, and staying in the ditch is within the
tiger's existing catch height. The final cliff/vine drop is untouched.

The tiger's native Aseprite source now contains twelve walk and twelve gallop
poses. Stance and lifted recovery arcs are continuous, fore/hind legs are
staggered, knees fold during recovery, and the tail follows the body. Playback
scales with travel speed; gait changes carry their phase across a threshold
deadband. Route height changes use a capped vertical follow instead of a snap.
Respawn still resets directly to the full starting gap.
The slower story-tween walks use the same travel-based timing, pause their paws
at a pacing turn, and restore normal playback when switching to a roar/look.

Verification: `act3_chase_pit_test.tscn` drops the real player into both imported
ditches, checks art/collision agreement, escapes using actual jump/right input,
then waits for the real pursuer to catch him at rim height. It also checks
stride transfer, speed scaling and bounded height following. `-- --capture`
captures rendered gameplay. Existing animation, chase, story and route tests
cover the art and the onward run through rooms 28–30.
