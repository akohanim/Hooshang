Circuit prototype material reuses the existing Act2 key's Pixellab source swatch
(`assets/props/key/source/act2_key.png`, original seed 2205). This copy records
provenance; no generated bitmap is reduced into gameplay art. The procedural
16px diamond and 8px gate bar sample its palette, following the established
Act2 watercolor-influenced/crisp-edge pipeline. Rebuild with
`python3 tools/gen_prison_circuits.py`. Native readability review is pending.

`timed.png` is a 64×16 procedural sheet using the same sampled source ramp:
16×16 frames at x=0/16 are the lever's idle/active positions; x=32/48 are the
unbanked/banked relay badge. `tools/gen_prison_circuits.py` regenerates both
sheets. Geometry is drawn at native resolution, with no bitmap downsampling.
