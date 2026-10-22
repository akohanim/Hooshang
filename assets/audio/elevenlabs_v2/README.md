# ElevenLabs audio, second batch (2026-10-11)

Generated on the **Starter plan (commercial license)** — unlike the earlier
free-plan prototype cues in `../act2_elevenlabs/`. `manifest.json` records every
prompt and setting; `source/` keeps the raw MP3s (hidden from Godot by
`.gdignore`, so they never reach an export). No API key is stored anywhere:
the generators read `XI_API_KEY` from the environment (the music generator
also falls back to `~/.config/elevenlabs/api_key`).

## Music (ElevenLabs Music, `music_v1` / `music_v2_5`, 2 min each)

| File | Plays | Loop |
|---|---|---|
| `assets/music/prison_theme.ogg` | Act 2 prison hub and wings (`act2_music.gd`, cue PRISON) | 16 bars @ 60 BPM, 64 s |
| `assets/music/darkshang_theme.ogg` | Act 1 Darkshang chase, Level_14–25 (`act1_music.gd` `chase_stream`) — "Escape From Homayun", oud + darbuka lead, made by hand in the ElevenLabs Music web app | the whole 120 s piece: its four 30 s sections (15 bars each @ 120 BPM) in order |

| `assets/music/menu_theme.ogg` | The title screen (`MainMenu.tscn`'s `MenuMusic`) — `music_v2_5`, prompt in `tools/gen_elevenlabs_music.py`: ney lead in Dashti over santur/setar, 76 BPM, warm, sparse daf | its 7.2 s opening once, then 21 bars @ 76 BPM, 66 s (`loop_offset` 7.1586) |
| `assets/music/sea_sunrise.ogg`, `way_home.ogg`, `tall_grass.ogg`, `tiger_chase.ogg`, `vine_peril.ogg`, `the_lemon.ogg` | Act III from the real sea to the end (`act3_music.gd`), scored to the story — see `assets/music/README.md`'s "the way home". `music_v2_5`, prompts in `tools/gen_elevenlabs_music.py`; the chase is the second, drum-led take (`tiger_chase_b`; the first, `tiger_chase`, is kept in `source/`) | per `manifest.json` `music.<name>.loop`; `the_lemon` is a one-shot |

`tools/master_elevenlabs_music.py` finds the bar-aligned loop whose end best
matches its start, crossfades the seam over one bar, and levels both to
-17 dBFS RMS (the garden score's level). A track listed in its `INTRO` keeps
the generated opening ahead of the loop, and the printed `loop_offset` goes
into that `.ogg.import` by hand so Godot loops back past it. The replaced chase
mix, `darkshang_shur_requiem.ogg`, is kept for comparison.

## Sound effects (Sound Effects v2) — played through the `Sfx` autoload

| Cue | Variations | Where |
|---|---|---|
| `step_scaffold` | 4 | footsteps on Act 1 scaffolding ONLY, at -25 dB; a landing on scaffolding plays one 3–6 dB louder (read off the tile, see `surfaces.json`) |
| `ladder` | 4 | climbing, one per 10 px, quiet |
| `swim` | 3 | paddling, one stroke per 0.55 s |
| `jump`, `land` | 1 each | `Juice.on_jump` / `on_land` (landing thud scales with the drop) |
| `wall_jump` | 2 | `Juice.on_jump` off a wall, at -24 dB: a soft scuff, peak within 20 ms and gone by ~120 ms, so a chimney climb of back-to-back kicks stays crisp. Takes 3 and 6 of six; the other four were 150–250 ms scrapes that smear when chained |
| `splash` | 1 | falling or jumping into water |
| `crumble_warn` | 2 | a gritty stone rattle the instant a crumbling platform arms (its 0.6 s jitter), at -32 dB — barely there |
| `crumble_break` | 3 | the crack and clatter at the moment the blocks drop (`_drop`), at -29 dB |
| `death` | 2 | the deep muffled "oom": the thought swallowing him (`Juice.on_death`), at -3 dB so it carries over the music |
| `darkshang_gather`, `darkshang_lunge` | 1 each | Darkshang's surge/charge telegraph and launch |

No footsteps on brick, stone or grass, by design: a sound on every stride
everywhere is noise; the clank of a steel deck tells you where you are.
Retired cues (kept in `source/` and the manifest, marked `unused`):
`step_stone`, `step_grass`, the single-swell `crumble`, `respawn` (a breath
0.5 s after the death that read as the death arriving late), and `checkpoint`
(checkpoints are silent by design). Multi-take cues ship only the takes listed
in the manifest's `keep`, chosen by measuring attack, length and brightness —
the crumble rattle's slow-swell take and every bright/sparkly death take were
rejected.

Masters: mono 44.1 kHz 16-bit WAV, leading silence trimmed at -45 dB, peak
-3 dBFS, 3 ms / 25 ms fades. Scaffold, stone and ladder steps are four separate
single-event takes; grass and swim were one clip of several events, sliced at
their onsets (the model delivered even events for those two, not the others).

## Regenerating

```
XI_API_KEY=... python3 tools/gen_elevenlabs_sfx.py step_stone   # or no args: all missing
python3 tools/master_elevenlabs_sfx.py
python3 tools/gen_elevenlabs_music.py menu_theme   # key: XI_API_KEY or ~/.config/elevenlabs/api_key
python3 tools/master_elevenlabs_music.py prison_theme darkshang_theme menu_theme
python3 tools/gen_footstep_surfaces.py      # after changing Act 1's Collisions auto-rules
```

Checks: `tests/sfx_test.tscn`, `tests/act2_music_test.tscn`,
`tests/darkshang_music_test.tscn`.

### Darkshang history
1. taiko/strings cinematic (`source/darkshang_theme_taiko_v1.mp3`) — too Hollywood
2. tombak/darbuka-led (`source/darkshang_theme_tombak_v2.mp3`) — no melody
3. drums + dark melody, then the same with a separately mixed melody stem
   (`source/darkshang_theme_layered_bed.mp3` + `source/darkshang_melody_stem.mp3`,
   `tools/layer_darkshang_melody.py`) — melody still not coming through in play
4. **current:** "Escape From Homayun" (`source/darkshang_theme.mp3`), oud and
   darbuka, made by hand as four chained 30 s loop sections; played whole
   (`FIXED_LOOPS` in master_elevenlabs_music.py), levelled, no layering.
