# Rumi animation source sheets

Update: these sources have now been prepared and integrated. The game-ready
atlases and preparation notes are in `assets/characters/rumi/sprites/`, built
by `tools/prepare_rumi_sprites.py`. `game_idle.png`, `game_walk.png`, and
`game_give_glow.png` show the final sprites rendered in the actual game.
`in-game-animations.gif` previews the prepared frame cycles. The source-sheet
limitations below describe the original generations, not the final atlases.

Generated with the built-in image_gen tool using ../rumi-gameplay-style-preview.png as the approved design reference.

- idle.png: 4 frames in one row. Suggested playback: 4 fps, loop.
- walk.png: 8 frames in 4 columns by 2 rows. Suggested playback: 8 fps, loop.
- give_glow.png: 6 frames in 3 columns by 2 rows. Suggested playback: 6 fps, once.
- walk-transparent.png and give_glow-transparent.png: background extraction variants.

These are generated source sheets, not native-resolution game-ready atlases. Walk and give_glow originals have baked checkerboard backgrounds. The transparent variants contain partial-alpha edge artifacts; the give_glow extraction also introduced soft halos. Prefer the original give_glow art as the cleanup source. Native-resolution conversion, palette cleanup, frame alignment, and animated playback verification remain necessary before integration. Existing Rumi resources and gameplay are unchanged. Read frames left to right, then top to bottom. Appearance/disappearance can continue using existing Godot fades. Mirror right-facing frames for left-facing use.

## Generation prompts

### idle

Use the attached approved Rumi image as the exact character design reference. Generate a production sprite sheet, transparent background with true alpha, no checkerboard drawn into the art. Preserve the extremely simple chunky low-resolution pixel style: orange turban, tiny tan face and one dark eye facing RIGHT, white pointed beard, plain dark green long coat over plum robe, brown boots. No sword. No embroidery or added detail. Each figure should have approximately 12x28 logical pixels, enlarged uniformly with square hard-edged pixel blocks. Identical proportions, palette, turban and beard across frames. No text, labels, grid lines, floor shadows or scenery. Full bodies and feet visible, uniform equal-sized frame cells, common foot baseline and anchored body position within every cell. Transparent gutters prevent any overlap. Animation: IDLE. EXACTLY FOUR frames in ONE HORIZONTAL ROW of four equal square cells. A very subtle breathing loop: neutral, chest slightly rises, breath crest with eyelid blink, returns toward neutral. Feet stay absolutely planted and same size. Only one logical pixel of chest/shoulder motion; no body warping. Output aspect ratio 4:1, clean atlas of four frames.

### walk

Use the attached approved Rumi image as the exact character design reference. Generate a production sprite sheet, transparent background with true alpha, no checkerboard drawn into the art. Preserve the extremely simple chunky low-resolution pixel style: orange turban, tiny tan face and one dark eye facing RIGHT, white pointed beard, plain dark green long coat over plum robe, brown boots. No sword. No embroidery or added detail. Each figure should have approximately 12x28 logical pixels, enlarged uniformly with square hard-edged pixel blocks. Identical proportions, palette, turban and beard across frames. No text, labels, grid lines, floor shadows or scenery. Full bodies and feet visible, uniform equal-sized frame cells, common foot baseline and anchored body position within every cell. Transparent gutters prevent any overlap. Animation: WALK cycle, exactly EIGHT frames arranged in a precise FOUR COLUMN TWO ROW grid, reading left to right then top to bottom. Each cell equal size, one character in center of each cell. Eight clearly different consecutive poses: right foot forward contact, weight down, legs passing, lift, left foot forward contact, weight down, legs passing, lift back toward frame one. Slow dignified elderly walk, modest stride, opposite arm swing and slight coat hem sway; no running, no jumping. Keep torso and head shape consistent, body location fixed for an in-place loop. All face right throughout. Output landscape 2:1 canvas.

### give_glow

Use the attached approved Rumi image as the exact character design reference. Generate a production sprite sheet, transparent background with true alpha, no checkerboard drawn into the art. Preserve the extremely simple chunky low-resolution pixel style: orange turban, tiny tan face and one dark eye facing RIGHT, white pointed beard, plain dark green long coat over plum robe, brown boots. No sword. No embroidery or added detail. Each figure should have approximately 12x28 logical pixels, enlarged uniformly with square hard-edged pixel blocks. Identical proportions, palette, turban and beard across frames. No text, labels, grid lines, floor shadows or scenery. Full bodies and feet visible, uniform equal-sized frame cells, common foot baseline and anchored body position within every cell. Transparent gutters prevent any overlap. Animation: GIVE GLOW POWER-UP, EXACTLY SIX frames arranged in THREE COLUMNS by TWO ROWS, read left to right, top row then bottom row. One consistent Rumi in each equal cell, stationary planted feet. Frame 1 neutral idle arms lowered. Frame 2 bends forward arm to chest level. Frame 3 raises cupped hand forward, a tiny gold pixel spark forming above palm. Frame 4 extends hand to the right with small bright golden orb just beyond the palm. Frame 5 releases orb to the right, a few discrete gold pixels trailing it; hand remains extended. Frame 6 lowers empty hand back toward idle. Keep gold effect within its cell. Small hard-edged yellow/gold/ivory pixel clusters only, no blurred lighting bloom. Preserve base character size throughout. No text. Canvas landscape aspect 3:2.

### walk_alpha

Background extraction edit. Remove the entire white and light grey checkerboard background from this sprite sheet and output a genuinely TRANSPARENT RGBA PNG with alpha zero outside each sprite. Keep all eight characters, their exact poses, white beards, colors, sizes, positions and the 4-column 2-row layout unchanged. Do not draw a checkerboard or any replacement background. Preserve hard pixel edges.

### give_glow_alpha

Background extraction edit. Remove the entire white and light grey checkerboard background from this sprite sheet and output a genuinely TRANSPARENT RGBA PNG with alpha zero outside each sprite. Keep all six characters and all yellow golden light particles, exact poses, white beards, colors, sizes, positions and 3-column 2-row layout unchanged. Do not draw a checkerboard or any replacement background. Preserve hard pixel edges and all white beard pixels.

### give_glow_alpha_retry

Extract these SIX pixel-art sprites onto transparent alpha background. Keep the existing 3 columns 2 rows and all poses exactly. Background must be fully transparent, NOT a checkerboard, NOT black. HARD CUTOUTS ONLY: absolutely NO colored halo, NO blur, NO bloom, NO light spill anywhere, especially around turban and body. Keep original muted colors and white beards. Yellow squares in the last poses are solid pixel shapes ONLY, they emit NO visible light or halo. All pixels outside the solid character shapes and solid yellow square shapes must have alpha exactly zero. Preserve positions and sizes. Transparent PNG sprite atlas.
