# Hooshang pixel portrait set

Approved reference: `approved_base.png`, the younger Hooshang with tucked ears,
brown cardigan, blue shirt, moustache and clean jaw. This supersedes the
painted cardigan_v1 runtime artwork. Rumi remains unchanged.

## Research and frame plan

Consulted Adobe's [mouth-shape tutorial](https://www.adobe.com/learn/adobe-character-animator/web/lip-sync-mouth-shapes)
and [character tutorials](https://pages.adobe.com/character/en/tutorials) on 2026-09-11.
These describe mouth-shape libraries and separate eyelid/blink animation.
For this game's text-driven speech blips, the chosen compact vocabulary is
closed, parted, AH, OH and EE. This is expressive speech animation, not
phoneme-accurate synchronization to recorded speech.

Every expression has 15 frames: open eyes (0–4), half-closed eyes (5–9),
closed eyes (10–14), with the five mouths in that order in each row.
The existing independent blink clock traverses open/half/closed/half/open
over 0.20 seconds. Speech cycles mouth columns 1–4 at 9 fps and returns to
column 0 during pauses and at the end of a page, even while blinking.

All 16 Act1Beats.FACES states are covered: neutral, happy, angry, sad,
surprised, dazed, hesitant, skeptical, annoyed, vulnerable, shocked,
confused, wary, unconvinced, deflecting and flat. The Darkshang encounter
uses the same shocked and vulnerable asset paths. Story text is unchanged.

## Sources and runtime

Generated with built-in imagegen, one 5×3 sheet per expression, referencing
the approved base each time. Exact prompts are in `*_prompt.txt`; originals
are in `*_source.png`. Sheets contain approximately 324px square source cells.
512px runtime frames are nearest-resampled, not native 512px detail.

`tools/build_hooshang_pixel_portraits.gd` extracts and aligns the authored
facial regions and assembles eye/mouth combinations on a fixed expression
master. Narrow edge blending avoids visible cut boundaries; no replacement
features are drawn procedurally. Neutral frame 0 retains the approved image.
Neutral sheet placement needs a measured 18px upward adjustment at 512px.
The remaining expressions register each cell against their own rest pose.

Individual frames: `assets/characters/hooshang/portraits/pixel_v2/`.
Runtime stills and strips retain existing Hooshang paths so every Act 1
speaker reference picks up the replacement. Manifest entries mark
`source: pixel_v2` and `pixel_art: true`; the latter selects nearest filtering
only for these portraits and resets when switching speakers. Voice aliases
and existing blink/speech behavior remain in use.

Rebuild with Godot --headless --path . --script res://tools/build_hooshang_pixel_portraits.gd.
Validate with res://tests/hooshang_pixel_test.tscn. Render the real banner with
res://tests/hooshang_pixel_preview.tscn -- --capture.
