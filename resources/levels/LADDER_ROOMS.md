# V10–V14 ladder overhaul

The September 10 ladder pass supersedes these five rooms' geometry in
DARKSHANG_REDESIGN.md. Their identifiers, world placement, sequence in Act 1,
and story dialogue are preserved. The later security-console
pass replaces their earlier waiting/phase/abstract-pad rules.

- **V10 / The Other Shift:** charge three consoles on the raised decks,
  following the lit numbers through the long climbs and thought crossings.
- **V11 / Trace the Circuit:** charge the first console, cross to the higher
  third deck, then return to the middle console. Numbers communicate the order.
- **V12 / Negative Space:** charge the lower-left console, climb to the upper
  left, descend to the lower-right console, then climb to the exit. The old
  full-height phase door is removed; both shafts are always accessible.
- **V13 / Between the Hands:** four numbered consoles create a longer circuit
  across the alternating decks, preserving the orbit and diagonal crossings.
- **V14 / Do Not Follow:** three consoles lead across the shorter chamber
  before the final exit-ladder climb.

## Security consoles and exit gates

Every room uses one interaction: stand still at the lit console for 0.8 seconds.
A downward marker identifies the active console; a charge bar shows progress.
Completed consoles display a green checkmark and play a confirmation tone.
A future console names the number to activate first. Wrong-order contact does
not erase progress, and completed consoles remain charged after death even
before a checkpoint. Returning to a room starts a fresh circuit.

The prefab `scenes/props/security/SecurityGate.tscn` covers only the 32x32 exit
opening and displays the circuit's completed/total count. On completion its
steel shutters retract and it reads OPEN. The logical exit also checks the lock,
so jumping around the doorway or teleporting into the trigger cannot bypass it.
There are no full-height gate columns or phase barriers in V10–V14.

These five rooms use the world's authored ambient color, exactly as Level_1
uses it. Darkness manifestations no longer dim or pulse their ambient light.

All five rooms have all three thought tones. There are 23 ladder entities and
23 moving thoughts in total. Patrol speeds range from 0.16 to 0.235 cycles per
second, with staggered phases and clockwise/counterclockwise orbits. Vertical
patrols guard the landing side of a ladder so they cannot permanently block
its shaft. Hold up/down to climb; jump toward a scaffold to dismount.

Every raised deck is real solid connected-scaffolding tiles (Collisions value
5), not a platform prop or decorative overlay. Masonry end sockets are omitted
beside the shafts to keep the player's full-width hitbox clear. There are no
spike entities or painted hazard tiles. Recovery floors and one intermediate
checkpoint per room permit retries without losing the entire climb.

Authoring lives in `resources/levels/act1_expansion.json`. Rebuild only these
rooms with the editors closed:

```sh
python3 tools/build_act1_expansion.py --install --rooms Level_V10 Level_V11 Level_V12 Level_V13 Level_V14
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

`tests/ladder_overhaul_test.tscn` exercises every ladder with live thoughts,
including real input, dismounts, scaffold landings, and a same-rail death/retry.
`tests/darkness_geometry_test.tscn` now understands the ladder routes alongside
the existing escape-room jumps. `tests/darkness_playthrough_test.tscn` exercises
complete puzzles and exits; its pilot waits for patrol openings but never
freezes hazards, grants immunity, or teleports past a route leg.

`tests/ladder_overhaul_preview.tscn` saves full-room layout renders under
`output/ladder_overhaul/`. For actual gameplay with the world backdrop and
normal camera, run `tests/darkness_preview.tscn` (starts at V10 without a save).

`tests/security_gate_test.tscn` verifies real gate collision, clear space above
and below the doorway, anti-bypass authorization, numbered charge feedback,
phase-independent activation, death persistence, opening animation, and exact
Level_1 ambient-color equality. `tests/security_gate_prototype.tscn` renders the
five rooms with the authored ambient color into `output/security_gate/`.

Recipe-only changes require invalidating the active generated world import
cache before importing: the LDtk file's geometry bytes can be unchanged while
the post-import recipe data changes. Confirm the importer actually logs
`Finished Import` and test the loaded room's recipe, not just the JSON source.
