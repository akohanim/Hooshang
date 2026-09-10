#!/usr/bin/env python3
"""Act 2 Watercolor Parallax Layer Generator (Option C: Parallax Layer Separation).

Decomposes hooshang_act2_background.jpeg into 4 distinct RGBA depth planes:
  - Layer 0: Sky Dome & Celestial Sun (with upward zenith sky pad)
  - Layer 1: Watercolor Clouds (soft alpha cutout, horizontally seamless)
  - Layer 2: Mountain Ridge (anti-aliased ridge cutout, horizontally seamless)
  - Layer 3: Near Sand Dunes & Valley Floor (with downward sub-floor pad, horizontally seamless)

Usage:
  python3 tools/gen_act2_parallax_layers.py
"""

import os
import shutil
from pathlib import Path
from PIL import Image, ImageFilter
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
SRC_PATHS = [
    Path("/Users/ari/Downloads/hooshang_act2_background.jpeg"),
    ROOT / "assets" / "backdrop" / "act2_sky" / "source" / "act2_sky_watercolor.jpg"
]
OUT_DIR = ROOT / "assets" / "backdrop" / "act2_parallax"
BRAIN_DIR = Path("/Users/ari/.gemini/antigravity/brain/6a91f23e-28a6-4cdd-97a4-d01d5bc93226")

OUT_DIR.mkdir(parents=True, exist_ok=True)


def find_source() -> Path:
    for p in SRC_PATHS:
        if p.exists():
            return p
    raise FileNotFoundError("Could not locate source background image.")


def make_seamless_horizontal(img_arr: np.ndarray, blend_w: int = 180) -> np.ndarray:
    """Seamlessly blend right edge into left edge so repeat_size.x tiles infinitely with 0 seams."""
    h, w, c = img_arr.shape
    final_w = w - blend_w
    left = img_arr[:, :blend_w]
    right = img_arr[:, final_w:w]

    t = np.linspace(0, 1, blend_w).reshape(1, blend_w, 1)
    smooth_t = 0.5 * (1.0 - np.cos(np.pi * t))

    out = img_arr[:, :final_w].copy()
    out[:, :blend_w] = (1.0 - smooth_t) * right + smooth_t * left
    return out


def generate_layers(scale: float = 0.5) -> None:
    src_path = find_source()
    print(f"Loading source: {src_path}...")
    img = Image.open(src_path).convert("RGB")
    arr = np.array(img, dtype=np.float32)
    h, w, _ = arr.shape
    print(f"Source size: {w}x{h}")

    # =========================================================================
    # 1. LAYER 0: Sky Dome & Sun (Rows 0..1100 + upward zenith sky padding)
    # =========================================================================
    print("Generating Layer 0: Sky Dome & Sun...")
    sky_crop = arr[:1100, :].copy()
    zenith_pad = np.repeat(sky_crop[0:1, :], 250, axis=0)
    noise = np.random.normal(0, 1.5, zenith_pad.shape)
    zenith_pad = np.clip(zenith_pad + noise, 0, 255)
    layer0_rgb = np.vstack([zenith_pad, sky_crop])

    l0_h, l0_w, _ = layer0_rgb.shape
    layer0_alpha = np.ones((l0_h, l0_w), dtype=np.float32) * 255.0
    fade_h = 100
    layer0_alpha[-fade_h:, :] = np.linspace(255, 0, fade_h)[:, None]
    layer0_rgba = np.dstack([layer0_rgb, layer0_alpha]).astype(np.uint8)

    # =========================================================================
    # 2. LAYER 1: Watercolor Clouds (Rows 350..1000)
    # =========================================================================
    print("Generating Layer 1: Watercolor Clouds...")
    clouds_rgb = arr[350:1000, :].copy()
    cl_h, cl_w, _ = clouds_rgb.shape
    r, g, b = clouds_rgb[:, :, 0], clouds_rgb[:, :, 1], clouds_rgb[:, :, 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b

    cloud_density = np.clip((238.0 - lum) / 45.0, 0.0, 1.0)
    v_feather = np.ones(cl_h, dtype=np.float32)
    v_feather[:60] = np.linspace(0, 1, 60)
    v_feather[-60:] = np.linspace(1, 0, 60)
    cloud_alpha = cloud_density * v_feather[:, None] * 255.0
    cloud_alpha_smooth = Image.fromarray(cloud_alpha.astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0))
    layer1_raw = np.dstack([clouds_rgb, np.array(cloud_alpha_smooth)])
    layer1_rgba = make_seamless_horizontal(layer1_raw, blend_w=200).astype(np.uint8)

    # =========================================================================
    # 3. LAYER 2: Mountain Ridge (Rows 1000..1500)
    # =========================================================================
    print("Generating Layer 2: Mountain Ridge...")
    mount_rgb = arr[1000:1500, :].copy()
    m_h, m_w, _ = mount_rgb.shape
    mr, mg, mb = mount_rgb[:, :, 0], mount_rgb[:, :, 1], mount_rgb[:, :, 2]
    warmth = mr - mb
    mount_alpha = np.zeros((m_h, m_w), dtype=np.float32)

    for y in range(m_h):
        if y < 40:
            continue
        elif y > 250:
            mount_alpha[y, :] = 255.0
        else:
            w_factor = np.clip((warmth[y] - 12.0) / 20.0, 0.0, 1.0)
            b_factor = np.clip((232.0 - mb[y]) / 22.0, 0.0, 1.0)
            y_prog = (y - 40) / 210.0
            val = np.maximum(np.minimum(w_factor, b_factor), y_prog * 0.8)
            mount_alpha[y, :] = np.clip(val * 255.0, 0, 255)

    mount_alpha_smooth = Image.fromarray(mount_alpha.astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
    layer2_raw = np.dstack([mount_rgb, np.array(mount_alpha_smooth)])
    layer2_rgba = make_seamless_horizontal(layer2_raw, blend_w=200).astype(np.uint8)

    # =========================================================================
    # 4. LAYER 3: Near Dunes & Floor (Rows 1380..2048 + downward floor padding)
    # =========================================================================
    print("Generating Layer 3: Near Dunes & Floor...")
    dunes_rgb = arr[1380:2048, :].copy()
    floor_pad = np.repeat(dunes_rgb[-1:, :], 250, axis=0)
    floor_noise = np.random.normal(0, 1.5, floor_pad.shape)
    floor_pad = np.clip(floor_pad + floor_noise, 0, 255)
    dunes_extended = np.vstack([dunes_rgb, floor_pad])
    de_h, de_w, _ = dunes_extended.shape
    dunes_alpha = np.ones((de_h, de_w), dtype=np.float32) * 255.0
    dunes_alpha[:100, :] = np.linspace(0, 255, 100)[:, None]
    layer3_raw = np.dstack([dunes_extended, dunes_alpha])
    layer3_rgba = make_seamless_horizontal(layer3_raw, blend_w=200).astype(np.uint8)

    # =========================================================================
    # Save scaled layers
    # =========================================================================
    layers = [
        ("layer0_sky_sun.png", layer0_rgba),
        ("layer1_clouds.png", layer1_rgba),
        ("layer2_mountains.png", layer2_rgba),
        ("layer3_dunes.png", layer3_rgba),
    ]

    for filename, raw_rgba in layers:
        im = Image.fromarray(raw_rgba)
        new_w = int(im.width * scale)
        new_h = int(im.height * scale)
        scaled = im.resize((new_w, new_h), Image.Resampling.LANCZOS)
        out_file = OUT_DIR / filename
        scaled.save(out_file, optimize=True)
        # Also copy to brain dir for review
        if BRAIN_DIR.exists():
            scaled.save(BRAIN_DIR / filename)
        print(f"  -> Saved {filename} ({scaled.width}x{scaled.height}, {out_file.stat().st_size / 1024:.1f} KB)")

    # Create composite preview
    print("Generating composite preview...")
    l0 = Image.open(OUT_DIR / "layer0_sky_sun.png")
    l1 = Image.open(OUT_DIR / "layer1_clouds.png")
    l2 = Image.open(OUT_DIR / "layer2_mountains.png")
    l3 = Image.open(OUT_DIR / "layer3_dunes.png")

    canvas = Image.new("RGBA", (l0.width, int(l0.height * 1.5)), (200, 230, 240, 255))
    canvas.paste(l0, (0, 0), l0)
    canvas.paste(l1, (50, int(180 * scale)), l1)
    canvas.paste(l2, (50, int(480 * scale)), l2)
    canvas.paste(l3, (50, int(620 * scale)), l3)

    preview_path = OUT_DIR / "parallax_composite_preview.png"
    canvas.save(preview_path)
    if BRAIN_DIR.exists():
        canvas.save(BRAIN_DIR / "parallax_composite_preview.png")
    print(f"Composite preview saved to: {preview_path}")
    print("\nParallax layer generation complete!")


if __name__ == "__main__":
    generate_layers()
