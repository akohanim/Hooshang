# Prison precision revision progress

Implementation and verification are complete; the new macOS build is ready for
the user’s playtest. All gameplay evidence is scripted input or explicitly staged
testing. Human playtesting remains the final judgment of difficulty and feel.

- [x] Audit17 prison rooms and study Celeste Chapter3 through local map data.
- [x] Cafeteria R01–R03: deeper temporary-platform sequences, measured timing,
  late deaths/resets, earned key/shortcut/full reverse loop.
- [x] Library G01–G03: two-stone lesson, four-stone low crossing/reversal,
  five-note musical capstone; earned Green/shortcut/full reverse loop.
- [x] Exactly two musical key gates authored: G03 and Y03. Both pass ordered
  contact/save tests and now have earned key routes.
- [x] Nine dry vertical seams have partial wooden catch ledges and open side
  gaps. Staged upward/downward traversal passes; flooded seam remains water.
- [x] B01: roofed under/over/under swim lesson; two-way route and persistent
  sluice survive a real input-triggered retry.
- [x] B02: observed swim-patrol window, two dry crumble landings and permanent
  valve; safe water resets and water-exit animation timing verified.
- [x] B03: submerged under/over turns, observed patrol window, reversed return,
  dry recovery seal; earned Blue/shortcut and full basement reverse pass.
- [x] Y02 balcony: two collapsing landings, lower exit approach, banked timer,
  upward/downward entrance and reverse sequence; collapse/retry checked.
- [x] Y01 retained as the verified plate/wall-jump lesson. Y03 now combines
  consecutive wall jumps, five ordered notes, collapse/drop/air-dash reversal,
  timed seal and Gold shortcut; full gym reverse and recovery pass.
- [x] Sampled failure variants, landing/timing margins, wrong-note recovery,
  bypass probes, checkpoints and native presentation across all wings.
- [x] Both complete prison orders with midway save/load and rescue; full39-room
  Act2 run;40 directed portal checks;24 key-state permutations.
- [x] Clean imported macOS build exported, signature/ZIP checked, packaged UI
  inspected. See `prison_precision_verification.md` and the milestone index.

## Latest verified evidence

Gym: `output/prison_precision/gym_music/full_late.json` earns the entire wing,
misses one deliberately late beam recovery, retries from the real room-entry
checkpoint, collects Gold and retraces all rooms to Hub (one expected death,
no climb/mantle). `wrong_note.json` repeats note2, returns to1 and finishes
without death. Normal0.3s dwells and an earlier beam departure also pass.
Upper phrase6.13s to note5,1.875s timer margin at banking in the slower run.
Six regressions plus three final-shaft checks pass; both musical-gate staged
contact tests pass. Y01's hold/expiry/wall-jump/return lesson passes unchanged.
Native captures are in the same directory. The direct note3→4 skip probe fails safely. Both complete four-key missions
and the full-act run now pass; see the final verification report.

Y02: `output/prison_precision/gym_balcony/`. Two24px collapsing stones replace
its permanent middle rest;6.5s plate grace. Forward/entrance/reverse passes with
0.3s stone dwells and zero deaths; a first-stone overstay causes exactly one
hazard death, then restored checkpoint/stones and a successful full retry.
One single-jump skip probe fails before a successful retry. Native captures
confirm distinct crumble art, solid launch bank and partial wooden entrance.
Seven initial regressions pass in `checks/`. Final-bank smoke/world_bounds pass
in `final_checks/`; the shutter probe was ambiguous at the ledge edge and was
moved into the side gap, then passes in `gate_probe_check/`. The completed full gym loop is documented above.


B03 evidence: `output/prison_precision/basement_capstone/`. Full connected
Hub→Blue→shortcut→Hub and reverse through all basement rooms passes with zero
deaths/climb/mantle. A0.5s later patrol departure passes; a1.5s late departure
hits the patrol during the left turn. `late/route.json` verifies that actual
failure, dry respawn with the valve retained, then successful retry and Blue
shortcut (exactly one death). `retry/` separately checks a manual respawn after
the deep seal. Six regressions pass in `checks/`; native captures include the
deep seal and collected Blue. The upper dry seal remains a recovery beat.

B02 standalone evidence: `output/prison_precision/basement_stores/`. An actual
collapse into water restores stones without trapping the swimmer; a second
attempt earns the valve and returns through the room with zero deaths. A0.5s
later patrol departure plus0.3s stone dwells also passes. Seven regressions pass
in `final_checks/`. Full earned basement key/shortcut/reverse loop also passes with zero deaths
and no climb/mantle: `basement_stores/connected/full_route.json`. Native capture
confirms the patrol outline remains visible above water.

`output/prison_precision/basement_intro/connected/full_route.json`: earned full
basement loop with new B01 and existing B02/B03, all four basement circuits,
Blue key (captured), shortcut and full reverse to Hub; zero deaths/climb/mantle.
B01 retry uses the actual respawn input underwater, preserves the sluice,
restores dry footing, then repeats the round trip. Six relevant regressions
pass; flood_valve's stale coordinate was replaced with its imported position.
B03 difficulty redesign remains pending; B02 has since been rebuilt.

`output/prison_precision/library_stacks/connected/route.json`: all three library
circuits earned, Green collected, shortcut used, entire library retraced, Hub
finish; zero deaths and no climb/mantle. No position or puzzle-state grants.

G02 standalone: normal0.1s and delayed0.3s dwells pass on every0.6s stone;
landing targets shifted−3px/+3px pass. A deliberate collapse produces one death,
restores all four stones/checkpoint, then the same run earns the exit. One
floor-to-middle-stone bypass probe is blocked by the beam. Five regressions
pass: smoke, world_bounds, platform, prison_music_order, prison_circuit_save.
Evidence and native captures: `output/prison_precision/library_stacks/`.

Cafeteria evidence: `output/prison_precision/cafeteria_connected/`.
Library intro/music evidence: `output/prison_precision/library_intro/` and
`output/prison_precision/library_music/`. Entrance tests:
`output/prison_precision/entrance_ledges/`.

Design: `prison_precision_design.md`. Detailed experiments, earlier failures,
and historical checklists: `prison_precision_history.md`. Authoring scripts are
one-time recipes; never rerun them over later LDtk edits or restore their full
project snapshots. Preserve Act1, shared physics, artwork and dialogue.
