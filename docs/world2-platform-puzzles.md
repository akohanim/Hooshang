# World 2: platform puzzles after Level 2

Levels 3–8 are original Hooshang layouts. The later advanced extension adds
levels 9–13; see `docs/act2-advanced-levels.md`. Level 8 now continues onward,
and the chapter completion is at level 13. The earlier three rooms, story setup,
player physics, and room identifiers are preserved. The layouts use Hooshang's
springs, dash, crumbling platforms, steerable carpets, lemons, and garden art.

## Reference and interpretation

Read-only inspection of the installed Celeste map binaries found 38 rooms in
Forsaken City, with median dimensions 320×184 pixels; Old Site has 45 rooms with
the same median dimensions. Golden Ridge has 49 rooms, median 392×192. Counts
include connective and non-challenge rooms. Forsaken City contains 24 zip movers,
15 crumble blocks, and 20 strawberries; Old Site prominently uses dream blocks,
and Golden Ridge uses boosters and moving blocks. Player entries are spawn
records, not a count of checkpoints. No Celeste assets or room layouts were copied.

These observations, together with the description of Maddy Thorson's
[GDC level-design talk](https://www.gdcvault.com/play/1024307/Level-Design-Workshop-Designing-Celeste),
informed a design interpretation: introduce a readable movement idea, vary it,
combine familiar ideas, and offer optional risks. Binary counts alone cannot
establish whether a challenge feels fun. Hooshang retains its scrolling room
sizes; resting islands divide them into shorter challenges.

## Room sequence

- **3 — Saffron Steps:** an introductory jump, visible dash landings, a resting
  checkpoint, then an ascending remix.
- **4 — The Spring Courtyard:** steer three spring launches into visible landing
  pads; finish with a crumbling platform and dash transfers.
- **5 — Orchard of Choices:** a lower crumbling-platform chain or an upper spring
  detour with a bonus lemon. Both converge on a checkpoint terrace.
- **6 — Silk in the Wind:** steer a steadily advancing carpet through a hazard
  lane, rest, then transfer by spring into a second carpet puzzle.
- **7 — The Sky Garden:** combine spring steering, crumbling departures, dashes,
  and carpet steering. Checkpoints split the sequence into manageable retries.
- **8 — Garden of Kings:** a forgiving carpet flight and wider final landings,
  with a safe floor as relief after the preceding challenge.

Rooms 3–7 replace the previous continuous catch-floor with a hazard floor under
most of the route, so missed jumps lead to retries instead of bypassing puzzles.
Flags mark checkpoints. Decorative plants do not have collision. Lemons are
optional; collecting them is never required to advance.

## Editing and verification

With Act 2 closed in LDtk, run `python3 tools/build_act2_expansion.py`, then
`Godot --headless --editor --path . --script res://tools/import_act2_expansion.gd`.
The generator preserves levels 0–2 and writes both LDtk geometry and the route
recipes in `resources/levels/act2_expansion.json`. Do not edit imported scenes.

`act2_routes_test` plays each main solution continuously with real input, with no
position or velocity writes between obstacles. It separately plays the upper
Orchard branch. `act2_expansion_test` checks spring contact and headroom, initial
carpet support, checkpoint activation and death recovery. `act2_progression_test`
checks actual forward and return doorway transitions. Run ordinary timing, not
only fixed-FPS acceleration. Pass a room identifier after `--` to focus the route or prop test on one room.
The save-free `act2_expansion_preview.tscn` starts at
room 3; `-- --capture` records actual game-view screenshots.

Automated solutions establish reachability and retry behavior. Human playtesting
is still needed to tune perceived difficulty and enjoyment, especially the timed
crumbling-platform departures and vertical carpet steering.
