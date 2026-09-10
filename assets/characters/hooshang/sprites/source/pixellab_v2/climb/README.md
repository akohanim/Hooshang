# Climb — PixelLab v2 (native pixel art, not the GPT/Codex pipeline)

Generated directly with the PixelLab MCP, on a NEW state of the game's
existing Hooshang character rather than the Codex/GPT sheets used for the
other clips (see `assets/characters/hooshang/sprites/source/gpt_v1/`).

## Why a new character state

The Hooshang character already on file in PixelLab
(`f925bceb-1d54-4691-a381-54c9c729a97e`, "a Iranian-American office worker
in...") is the actual source of the game's *good*, native-resolution 88x88
frames (`running-6-frames`, `jumping-1`, `running-slide`, `breathing-idle`,
a custom wall-jump) — but it had drifted out of date: gray hair, a plain
cardigan with no knit pattern, and a thinner build than the character now
has in-game (after `tools/gen_chubby_hooshang.py`'s weight pass and the
newer GPT-generated clips).

`create_character_state` was used to bring it current without losing the
character's identity/skeleton:

```
character_id: f925bceb-1d54-4691-a381-54c9c729a97e
edit_description: "black swept curly hair instead of gray, a heavier and
  more portly build, cardigan sleeves with a tan-and-rust geometric knit
  pattern woven into them"
state_name: "Chubby (current)"
use_color_palette_from_reference: false
-> new character_id: 085ab187-f08d-43ff-929e-fdaa97e37475
   (group 63652a3f-781f-4e7b-aa33-70097ef11156, alongside the original state)
```

**This new character_id is the one to animate from now on** for any future
clip that wants genuine PixelLab pixel art matching the current look —
it already renders at the exact 88x88 canvas the game's SpriteFrames expect,
with no downscale/rescue pipeline needed (unlike the GPT sheets).

## The climb animation itself

```
animate_character(
    character_id="085ab187-f08d-43ff-929e-fdaa97e37475",
    action_description="climbing straight up a vertical surface, alternating
      arms reaching up and gripping overhead while alternating knees lift,
      steady rhythmic pull upward, weight shifting side to side with each
      reach",
    directions=["east"], mode="v3", frame_count=8,
)
-> animation group 7ffa9259-f38c-4bf3-a322-690ee7653761
```

`ref_0.png` is the character's standing reference frame (not part of the
animation). `ref_1.png`..`ref_8.png` are the 8 generated frames, copied into
`chubby/Climb/east/frame_000.png`..`frame_007.png` in that order.

**This did NOT come back as a true alternating stride** — same defect shape
as the GPT sheet's climb, different cause. The arm and knee simply keep
rising across all 8 frames (frame 8 ends with both feet off the ground, one
fist raised overhead) rather than repeating a left/right cycle, so playing
0..7 straight and looping back to 0 would pop badly. The identity/style is
right this time, though (unlike the GPT sheet, no defect there) — so rather
than discard it, it's played as a PING-PONG (0,1,2,3,4,5,6,7,6,5,4,3,2,1),
the same fix `swim`/`swim_idle`/`fall` use for exactly this "arc that never
returns to its own start" shape: reach-up-and-settle-back repeated reads as
continuous climbing effort. It is also symmetric enough to hold up
reasonably when `CLIMB`'s `speed_scale` sign reverses it for climbing down
— see `player.gd`'s own note on why CLIMB flips sign instead of splitting
into two states.
