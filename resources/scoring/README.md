# Act results

Run `scenes/ui/ActResults.tscn` with F6 for a self-contained fake Work result
(07:03, 8/8 lemons, 12 deaths, 14,470 points). Jump/confirm once skips the
tally, a second press closes the preview. It never loads a world or writes a save.

From the project directory:

```
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/ui/ActResults.tscn
```

`act_score.gd` contains all scoring constants and each act's title/par in seconds.
Acts 2 and 3 have provisional 600-second pars. Time points use whole seconds
remaining below par; scores never go below zero. An act with zero available
lemons does not receive the all-lemons bonus. There is no letter grade.
The global Points HUD uses the same lemon value; showing results does not award
those points again or replace the global run score.

`ActStats` counts from world load until the finale handoff. Dialogue is included;
SceneTree pause and results are excluded. Cosmetic time scaling is compensated.
The owner observes Screen/Collectibles/Deaths, with no player or room hooks.
Collection uses the saved unique IDs, not the spendable lemon balance. Available
lemons are the union of the loaded act's lemon IDs and its saved collected IDs,
scanned before queued removal of previously collected fruit.

SaveGame persists a separate `act_stats` slice. New acts reset it; continuing or
reloading the same act preserves it. Older saves have no per-act time/death history:
those measurements start on first load after this update; saved lemon IDs remain
counted. A new run gives complete stats from the start.

Future finales can use the same scene without modifying it:

```
var results = preload("res://scenes/ui/ActResults.tscn").instantiate()
results.stats = ActStats.finish()
get_tree().root.add_child(results)
await results.continued
results.queue_free()
# Resume the act's existing handoff here.
```

Act 1 uses this in its shared played/skipped finale handoff. It retains the
existing destination: the configured next scene, or the main menu if none exists.

Replace the placeholder audio resources `assets/sfx/results_tick.tres`,
`assets/sfx/results_line.tres`, and `assets/sfx/results_final.tres`, or assign
replacement AudioStreams to Tick, LineDone and FinalDone in ActResults.tscn.
They contain synthesized PCM ticks/chimes. Animation durations and tick interval
are exported on the results scene's root. Layout and font follow the existing
1280x720 UI surface scaled by 0.25, independently of the game viewport.

Regression test: `Godot --headless --path . res://tests/act_results_test.tscn`.
