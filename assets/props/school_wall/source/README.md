# School encounter material source

`materials.png`: built-in image generation, 2026-10-08. PixelLab's swatch tool
reported an expired subscription; no PixelLab asset was generated or charged.
The source is used only for color extraction. `tools/gen_school_wall.py`
authors native pixel geometry; it does not shrink or crop this bitmap into art.

Prompt: “Generate a square material color reference swatch for a 2D Iranian
school-prison game. Four clear regions: warm ivory plaster with restrained
watercolor gradients; deep turquoise cloth; ochre brass; charcoal polished
leather. A few terracotta accents. Detailed pixel art with watercolor-influenced
soft gradient shading, clean crisp pixel edges, restrained painterly bleed,
dynamic lighting, NOT flat 8-bit NES retro. Persian miniature flat-perspective
ornamental borders. This is reference art used only to extract color ramps for
procedural native 8px tile and 24px character art. No text, no characters, no
objects, no labels. Square image.”

The Persian first line is from Rumi's *Masnavi*, book one, section 50:
[Ganjoor source](https://ganjoor.net/moulavi/masnavi/daftar1/sh50/).
The author's English dialogue is unchanged. `tools/render_wall_poem.tscn`
uses the authoring machine's Geeza Pro font to rasterize the inscription;
the game ships only the resulting PNG, not that system font. Godot shapes
right-to-left Persian before rasterization.

The completed wall uses the matching second hemistich, `حفره‌کن زندان و خود را وا رهان`, verified against [Ganjoor, Masnavi I, section 50](https://ganjoor.net/moulavi/masnavi/daftar1/sh50/) on 2026-10-08. Render with `tools/render_wall_poem.tscn -- --second`; the game ships only the PNG. Both wall lines use the same font, size and ink. Spoken English remains the user's script verbatim.
