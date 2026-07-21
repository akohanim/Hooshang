# systems/

Autoload singletons — project-wide managers that persist across levels,
registered under `[autoload]` in `project.godot`.

Put **script-only** singletons here (a future `GameManager` for run state,
save data, act progression, etc.). A singleton that is really a **UI scene**
(like the dialogue box) can live with its scene in `scenes/ui/` and still be
registered as an autoload — see `Dialogue` → `res://scenes/ui/DialogueBox.tscn`.

Rule of thumb: reach for an autoload only for state/services that genuinely
outlive a single level. Per-level logic belongs on the level (see
`scripts/level_base.gd`), not here.
