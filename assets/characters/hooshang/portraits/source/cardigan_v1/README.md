# Hooshang — approved cardigan portrait and dialogue art

The user approved `approved_base.png`: smooth painted artwork, a warm brown
knit cardigan over a blue shirt, thick mustache, and a clean-shaven jawline.
This explicit direction supersedes pixel-art styling for these UI portraits.
The gameplay sprite and 320×180 world remain separate.

## Frame research and design

Adobe's [artwork preparation guide](https://helpx.adobe.com/adobe-character-animator/desktop/creating-and-controlling-puppets/prepare-artwork.html)
separates mouth shapes from eye/blink artwork and lists articulated mouth
shapes such as Ah, Ee, Oh and Neutral. Its
[trigger guide](https://www.adobe.com/learn/adobe-character-animator/web/use-triggers-to-control-animation-behaviors)
demonstrates multi-frame blinks and half-lowered eyelids. Consulted 2026-09-11.

For this game's synthesized blips and text-driven reveal, we choose a compact
five-mouth vocabulary rather than claim phoneme-accurate lip sync. Cross the
five mouths with three eyelid states to meet the requested 10–15 frames:

- Frames 0–4: eyes open; closed, slightly parted, AH, OH, EE mouths.
- Frames 5–9: eyes half closed; the same five mouths.
- Frames 10–14: eyes fully closed; the same five mouths.

Silence uses mouth column 0. Speech traverses columns 1,2,1,3,1,4,2,1 at
9 fps. Blinks independently select eye rows 0→1→2→1→0 over 0.20 seconds,
on the existing randomized blink clock. Mouth column 0 returns immediately
on a breath, page completion, or silence, including during a blink.

## Acting coverage

All sixteen `Act1Beats.FACES` states have their own art: neutral, happy,
angry, sad, surprised, dazed, hesitant, skeptical, annoyed, vulnerable,
shocked, confused, wary, unconvinced, deflecting, and flat. The last five
previously reused hesitant/skeptical art. The Darkshang trigger's shocked and
vulnerable portraits use the same replacement assets through their existing
paths. Act 2's child portraits and other speakers keep their existing art.

## Generation and packaging

Generated with the built-in imagegen tool, one 5×3 sheet per expression,
always referencing the approved base. Each `*_prompt.txt` records the exact
prompt, and each `*_source.png` preserves the returned artwork. Source cells
are approximately 324×324; final 512×512 runtime frames include resampling,
not a claim of 512 native pixels of generated detail.

`tools/build_hooshang_cardigan_portraits.gd` extracts the drawings, aligns
their noses, and assembles the eye/mouth combinations with feathered masks.
Each emotion uses its generated resting drawing as a fixed registration
master; neutral uses the exact approved base. This prevents head, hairstyle,
cardigan and background flicker within an emotion. There are no procedural
replacement eyes or painted-on geometric mouths.

Runtime strips: `assets/portraits/loops/hooshang_<state>_sheet.png`, 15 frames
in one horizontal strip. Individual PNG frames: `portraits/cardigan_v1/`.
Resting portraits retain the existing `portraits/hooshang_<state>.png` names.
The shared manifest marks these roles `authored_roles`, so the legacy role
detector will not overwrite them. Voice aliases in that manifest preserve
the established Hooshang voice pools without duplicating audio.

Rebuild from the repository root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/build_hooshang_cardigan_portraits.gd
```

The `source/` and individual-frame directories are ignored by Godot's importer
to avoid importing unused duplicate textures. Source files remain on disk
for rebuilding; only the runtime portraits and strips are consumed in game.
