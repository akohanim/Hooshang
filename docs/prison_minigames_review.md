# Prison hub minigames: defects found and fixed

Review of the hub's three machine games (2026-10-20): the shared `RetroTV`
prop, HOOSHANG 64, SUPER SIMORGH and THE OTHER SIDE. Each defect was found by
playing (scripted input through the real `Input` actions) or by reading the
code. Each one is fixed with a before and after measurement, or left with a
reason.

Proof:
- `tests/prison_minigames_test.tscn`: the TV, HOOSHANG 64 and SUPER SIMORGH.
- `tests/mirror_game_test.tscn`: THE OTHER SIDE, extended.
- `artifacts/prison_minigames/*.png`: before and after captures. They come
  from `tests/minigame_shot.tscn` and `tests/minigame_overlay_shot.tscn`. The
  HOOSHANG 64 "before" shots were rendered from HEAD's own `retro_game.gd`.

## The shared TV / PC (`scenes/props/prison/retro_tv.gd`)

| Defect | Before | After |
|---|---|---|
| The full-window picture was a fixed 1.5x of the 320x180 design space. That is whole window pixels only at even stretch factors. | At x9 (960x540 window on Retina, or a 2880x1800 / 3024x1964 fullscreen), the game pixels along one row were 80 at 14 px and 79 at 13 px wide | `RetroTV.picture_rect()` picks the largest whole-pixel size for the actual stretch. At x9, all 159 game pixels are 13 px. At x4 it is still 240x180. `tv_overlay_x9.png` |
| Dead hi-res / LINEAR-filter path (`hi_res`, `set_resolution`, `is_smooth`). No game implements it, and it would have smoothed pixel art. | Unused code that contradicts the pixel grid | Removed |
| Leave hints said ESC on a controller too | "ESC TO LEAVE" with a pad in hand | `RetroTV.leave_key()` gives ESC or START (`InputDevice`) |

## HOOSHANG 64 (`scenes/minigame/retro_game.gd`)

| Defect | Before | After |
|---|---|---|
| Respawning at the col-92 checkpoint put a walking enemy 32px away | Killed 1.15s after respawn with no input | No enemy starts within `SAFE_RESPAWN` (96px) ahead. The nearest is 144px, and he is still standing 5s later. `h64_checkpoint_respawn.png` |
| The 2-wide gap between the end staircases was a 6-deep well | A standing jump comes up 1-2px short of the rim. 12 of 60 scripted escape attempts got out | Two blocks of floor make it a 4-deep notch. A standing jump gets out from every spot in it, either way (10 of 10). `h64_stair_notch.png` |
| The course-clear walk ignored the ground | Walked off the flag block 8px above the grass, in the jump pose | Hops down and walks on the real ground with the run frames, then celebrates on screen. 0.00s airborne after the drop. `h64_flag_walkoff.png` |
| Title layout | Footer printed across the ground line. The mascot drawn over "ESC", standing 7px into the ground | The mascot's feet are on the ground, and the footer sits on the dirt clear of him. `h64_title.png` |
| A game over ejected you from the TV | `finished` led to a camera pull-out. Another go needed a walk back, Up, a 1.3s push-in, then Jump | Game over returns to the game's own title. Jump plays again with 3 lives. Only a course clear ends the session |
| Every blip clicked at its end | Each cue stopped dead at 28/127 (40% of its level) | Phase-continuous square wave plus a 6ms release. Every cue ends at 0 |
| **Not reachable in the shipped hub** | THE OTHER SIDE took the box TV. Nothing constructs a `RetroGame` (`RetroTV` only falls back to it) | **Left out on purpose (user's call, 2026-10-21).** It stays out of the hub and stays tested headless (`prison_minigames_test`), ready if it is ever placed |

## SUPER SIMORGH (`scenes/minigame/simorgh_game.gd`)

| Defect | Before | After |
|---|---|---|
| Controls not explained: it is first person (Up runs, Left/Right turn), but the title only said "C JUMP X RUN ESC LEAVE" | Holding Right (the platformer reflex) for 0.75s left him facing the wall as the dark closed in (`simorgh_held_right.png`) | Title line "UP GO  LEFT/RIGHT TURN". The run shows "HOLD UP TO RUN" until he is 1.5 cells in. `simorgh_controls.png` |
| Being consumed ejected you from the PC | `finished` led to a pull-out, plus a 6s unskippable card | Back to the title. Jump skips the card after 3.6s and starts the next run. Escaping still finishes |
| Music and drone restarted on `finished` | A gap at every loop seam, every 9.6s at normal pitch, though it was generated as a seamless loop | Looped in the stream (`LOOP_FORWARD`, end = frame count) |
| The santur ignored the pause menu's MUSIC: OFF | It played regardless | `Settings.music_enabled` gates it. The drone, heartbeat and scares (him, not music) stay |
| `jump` and `bump` cues were shorter than their plucks | Cut off mid-ring at 0.108 and 0.087 of full scale: a click on every jump | `gen_simorgh_audio.py` fades every one-shot's last 20ms. The loops are byte-identical |
| Balance (checked, not changed) | Docs said escape at ~27s, ~7 cells clear | Re-measured: escape at 28.6s, Darkshang never closer than 7.7 cells. A walker is caught at 25.5s. Idle is caught 2.7s into the chase. CLAUDE.md updated |
| Onset transients in `hit` / `stinger` (first sample 0.60 / 0.48) | — | **Left: deliberate.** It is the santur hammer's strike (`pluck`'s 6ms noise) and the scare's attack |

## THE OTHER SIDE (`scenes/minigame/mirror_game.gd`)

| Defect | Before | After |
|---|---|---|
| First-person view mirrored against the controls | Holding Right slid the room right on screen, as when stepping left. +y (his right hand) was drawn on the left | +y projects to the right. Strafing right now slides what is ahead to the left. `mirror_first_person.png` |
| First-person controls footer overflowed | "UP: GO  LEFT/RIGHT: STRAFE" (155px wide, drawn from x 11) ran past the 160px edge, cut to "STRAF" | "UP GO  LEFT/RIGHT STRAFE", centred, 143px |
| The timed gate (rooms 3 and 5) stopped at y 89, the start/goal line | Walking 3px lower bypassed it. A route search found a way round with the gate lit | It runs ceiling to floor. No route avoids it, and it kills at floor level when lit. `mirror_gate.png` |
| The 5x7 bitmap font drawn at sizes 8 and 9 | Strokes 1 and 2 px thick within the same word ("THE OTHER SIDE") | Only size 7, or a whole-number scale. Linted for all three games. `mirror_title.png` |
| No way out shown | Title said only "JUMP TO ENTER" | "JUMP ENTER  ESC LEAVE" (or START) |
| Point hitbox at the feet vs a 14x20 sprite | — | **Left: standard for top-down.** Every room's static-route check is built on it, and changing it would retune all five rooms |
| Chasers unseen in first-person room 4 | — | **Left: deliberate.** "THE PURSUER" is about being followed. The red edge bars are the feedback |

## Re-running

```
Godot --headless --path . res://tests/prison_minigames_test.tscn
Godot --headless --path . res://tests/mirror_game_test.tscn
Godot --path . res://tests/minigame_shot.tscn -- after
Godot --path . --windowed --resolution 960x540 res://tests/minigame_overlay_shot.tscn -- after
```
