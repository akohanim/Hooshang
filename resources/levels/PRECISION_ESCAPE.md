# Precision escape: levels 15–24

This replaces the repeated long ladder routes in the escape segment. The ten rooms now contain 70 transfers across compact, distinct routes. Room identifiers, world positions, the Level_14 story reveal, and the Level_25 homecoming are preserved. Player movement tuning is unchanged.

- **15 — Cut the Corner:** a low-headroom flat dash followed by an upward diagonal and alternating-height landings. A permanent midpoint lets the second phrase be retried independently.
- **16 — Switchback Well:** a vertical climb folded back over itself twice. Brake on the upper shelves before changing direction. Two checkpoints divide the ascent.
- **17 — No Second Step:** two collapsing chains, separated by a permanent checkpoint island. Landing restores the dash, but the next jump must follow promptly. Darkshang pursues without projectile attacks.
- **18 — Five Notes Home:** the five numbered musical blocks are the platforms. Land on 1–5 to open the exit shutter and restore the room's light. The lower floor permits recovery and restarting a wrong sequence. No pursuit, no checkpoint that could strand a reset melody behind the player.
- **19 — The Long Way Down:** a descending well, an air-braking reversal and a final upward recovery. A hanging wall prevents a direct shortcut across the top.
- **20 — Needle Thread, first crux:** long rising diagonal dashes onto 24px shelves; then a flat transfer under a spiked lintel and a rising dash out of its end. A checkpoint separates the two phrases. Neither an ordinary jump nor a flat dash clears the opening transfer.
- **21 — Against the Belt:** conveyor takeoffs, a raised stable perch, and another moving approach. Darkshang follows; no overlapping projectile puzzle competes with the movement.
- **22 — Folded Stair:** a taller ascent with rightward and leftward reversals, crossing above the earlier route before the final climb. Two stable checkpoints.
- **23 — Last Shift, final crux:** collapsing ascent, dash under the spiked lintel, reverse upward, and descend through a last collapsing chain. Two permanent balconies split the three phrases. Its opening transfer also requires an upward diagonal dash.
- **24 — One Last Breath:** a short, stable alternating-height finish. No additional lock or pursuer before the preserved homecoming.

## Authoring

`act1_expansion.json` remains authoritative. New generator fields: `deck_depth` sets a deck's actual thickness; `note_landings` replaces a route deck with its 16px musical block; `scaffold_sockets: false` keeps narrow landing widths exact; `spikes` places existing directional spike prefabs.

With LDtk and Godot editors closed:

```sh
python3 tools/build_act1_expansion.py --install --rooms Level_15 Level_16 Level_17 Level_18 Level_19 Level_20 Level_21 Level_22 Level_23 Level_24
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

The builder invalidates only this world's generated import cache on installation. The post-import hook embeds the encounter recipe, so a recipe-only change must rebuild even when the LDtk geometry's hash is unchanged.

## Playing and verification

Save-free preview, starting at level 15 (append `-- Level_20` to start at a particular room):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tests/precision_escape_preview.tscn
```

`precision_escape_test.tscn` uses ordinary controller input from every room's entrance through the real exit. The fixture in `tests/data/precision_escape_inputs.json` records jump holds, dash timing, direction and takeoff position. The continuous run does not teleport between platforms, disable hazards, grant immunity or open gates directly. All ten complete runs pass, including actual note contacts and live pursuit in 17/21.

`precision_escape_contract_test.tscn` checks every added checkpoint through real contact, death and safe respawn, checks pursuit/relief selection, and proves the two opening crux transfers reject a plain jump and a flat dash while accepting an upward diagonal. `music_exit_test.tscn` checks wrong order, room isolation, four-note rejection, gate collision, lighting and death reset. These pass, as do the route-order, world-bounds and preserved finale tests.

Full-room captures and actual 320×180 gameplay captures are under `output/precision_escape/`. These were inspected for terrain, spikes and note readability. Automated traversal proves reachability and sequencing; difficulty and enjoyment still benefit from a human playthrough.

The required 34-suite regression run finishes with 25 passes and nine pre-existing failures/timeouts: backtrack, Level_v6 return race, intro, death, slide, conveyor, save, jump tutorial and pause. The earlier baseline also failed chimney; it passed in the final run. The rebuilt switchback exposed a world-bounds test isolation issue (its highest ledge is an exit), fixed by disabling exit monitoring during that ceiling-only probe. No new regression failures remain. Logs and final statuses are in `output/precision_escape/final_regression_results.json`.
