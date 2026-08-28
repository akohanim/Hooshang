# Act II watercolor / Persian art direction — exploratory samples

Pure art experiment. Nothing here is wired into the game, `assets/`, `ldtk/art/`,
or any `tools/` generator. Generated via the Pixellab MCP (`create_image_pixflux`).
Safe to delete this whole folder at any time.

Goal: test whether a **watercolor treatment** (soft bled edges, paper grain,
translucent layered color) combined with **Persian ornament** (khatam marquetry,
tile mosaic geometry, muqarnas arch profiles) reads well once reduced to this
project's actual pixel-art scale, or turns to mud — and where on that spectrum
to land for Act II (warm / saturated / sun-drenched, vs. Act I's desaturated
office).

Every pair uses the same seed base and prompt skeleton, varied only on the
watercolor-softness knob: **hard** = heavy bleed + visible paper grain,
**pulled back** = watercolor-influenced gradient shading but crisp pixel edges,
restrained bleed. Reference language used in every prompt: "Persian miniature
painting flat-perspective linework," "khatam marquetry," "muqarnas arch
profile" — no generic "Arabian Nights" filler.

## Files

| File | What | Variant | Native size |
|---|---|---|---|
| `portrait_watercolor_hard.png` | Character bust test | heavy bleed, paper grain, lineless | 256×256 |
| `portrait_watercolor_pulled_back.png` | Character bust test | watercolor-influenced shading, selective outline | 256×256 |
| `tile_khatam_watercolor_hard.png` / `_4x.png` | Khatam/mosaic tile | heavy bleed | 64×64 (4× preview 256×256) |
| `tile_khatam_watercolor_pulled_back.png` / `_4x.png` | Khatam/mosaic tile | pulled back | 64×64 (4× preview 256×256) |
| `backdrop_archway_watercolor_hard.png` | Courtyard archway backdrop | heavy bleed | 240×132 |
| `backdrop_archway_watercolor_pulled_back.png` | Courtyard archway backdrop | pulled back | 240×132 |
| `prop_lantern_watercolor_hard.png` / `_4x.png` | Hanging lantern prop | heavy bleed | 48×64 (4× preview 192×256) |
| `prop_lantern_watercolor_pulled_back.png` / `_4x.png` | Hanging lantern prop | pulled back | 48×64 (4× preview 192×256) |

`_4x.png` files are plain nearest-neighbor upscales for on-screen review only
(no new detail) — generated locally with PIL, not by Pixellab.

The 256×256 portrait canvas and the tile/prop sizes intentionally exceed the
project's final in-engine dimensions (32×48 character, 8×8 tile). That's the
point of the test: these are concept-resolution samples to judge readability
*before* committing to a reduction pipeline like `tools/gen_chubby_hooshang.py`
or `tools/gen_thought_tiles.py` would need to build.

## Read on the results

**The heavy-bleed direction produces genuinely beautiful concept art, but I'd
be nervous running it through this project's reduction pipeline.** The soft
gradients and paper grain read gorgeously at 256px — the archway backdrop
especially — but that softness is exactly the information a nearest-neighbor
downsample and a hard color-count reduction (`reduce_colors`, or a script like
`gen_dark_thought.py`'s palette collapse) tend to destroy. Soft edges either
survive as blurry smears or get flattened into banding, neither of which reads
as "watercolor" anymore once you're at 8px-tile or 32×48-character scale — it
just reads as noisy. The khatam tile's hard-bleed variant is the clearest
warning sign: the individual star/cross motifs are already going soft at
native 64×64, well before any reduction toward an actual 8×8 tile.

**The pulled-back direction — watercolor-influenced gradient shading, crisp
pixel edges, restrained bleed — is the one I'd actually build the reduction
pipeline against.** It keeps the warm/saturated/sun-drenched palette and the
soft *shading* (which is squarely in-spec with this project's existing "soft
gradient shading, dithering, dynamic lighting" direction — this is not a
departure from the pipeline, it's an extension of it), while keeping shapes
legible enough to survive going small. The pulled-back portrait's embroidery
detail and the pulled-back tile's mosaic medallions both hold clean structure
at their native size, which is the leading indicator for holding up after
reduction.

**Recommendation:** don't treat "hard bleed" vs. "pulled back" as an either/or
for the whole Act — split by asset role, the same way `SunShaft`/`DarkThought`
already split "light" vs. "paint" by what each technique is actually for:

- **Gameplay-critical, tiled, or reduced-small assets** (character sprite,
  hazard/paintable tiles, small props that repeat) → pulled-back direction.
  These have to survive a real pixel-grid reduction and stay readable at a
  glance during play; heavy bleed is exactly what breaks that.
- **One-off, non-tiled set-piece backdrops** (an archway backdrop rendered at
  its own resolution and never squeezed onto the 8px grid, in the spirit of
  `SunShaft`/`WallPattern`) → heavy-bleed direction is worth it. Nothing forces
  it through a harsh reduction, so the paper-grain softness can survive intact
  and it's the more striking, distinctive art of the two.

If Act II moves forward with this direction, the next real test would be
running the pulled-back portrait and tile through an actual reduction pass
(crop/warp + `reduce_colors` to a ~32–48 color Act II palette, same shape as
`tools/gen_chubby_hooshang.py` / `tools/gen_thought_tiles.py`) to confirm it
holds up post-reduction, not just at concept resolution — this experiment only
tests the *concept*, not the pipeline.

## Prompts used (Pixellab `create_image_pixflux`)

**Portrait — hard:** "bust portrait of a warm Persian character in daylight,
heavy watercolor pixel art style with soft bled edges and visible paper grain
texture, translucent overlapping color washes, Persian miniature painting
flat-perspective linework, saturated warm palette of ochre gold turquoise and
rose, embroidered Persian textile collar with geometric khatam motif,
sun-drenched courtyard light" — `lineless` outline, seed 101.

**Portrait — pulled back:** same, swapped to "detailed pixel art with
watercolor-influenced soft gradient shading, clean crisp pixel edges... restrained
painterly bleed, not flat 8-bit NES retro" — `selective outline`, seed 102.

**Tile — hard:** "khatam marquetry mosaic tile pattern, geometric star and
cross Persian tilework, heavy watercolor pixel art with soft bled edges and
visible paper grain texture, translucent layered color washes, warm
sun-drenched palette of turquoise cobalt gold and terracotta, flat top-down
tile view, seamless repeating pattern" — `high top-down` view, seed 201.

**Tile — pulled back:** same, swapped to "detailed pixel art with
watercolor-influenced flat color shading and crisp pixel edges... restrained
painterly bleed" — seed 202.

**Backdrop — hard:** "Persian courtyard archway backdrop, pointed muqarnas
arch profile, sun-drenched warm daylight, heavy watercolor pixel art with soft
bled edges and visible paper grain texture, translucent layered washes,
tilework and khatam ornament on the arch, warm palette of ochre turquoise and
rose, side view game background" — seed 301.

**Backdrop — pulled back:** same, swapped to "detailed pixel art with
watercolor-influenced gradient shading, crisp pixel edges... restrained
painterly bleed" — seed 302.

**Prop (lantern) — hard:** "ornate Persian brass lantern with colored glass
panes, hanging courtyard lantern, heavy watercolor pixel art with soft bled
edges and visible paper grain texture, translucent color washes, warm
sun-drenched palette of gold amber and turquoise glass, small game prop icon"
— seed 401.

**Prop (lantern) — pulled back:** same, swapped to "detailed pixel art with
watercolor-influenced gradient shading, crisp pixel edges... restrained
painterly bleed" — seed 402.
