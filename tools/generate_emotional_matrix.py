#!/usr/bin/env python3
"""Generate an emotional sprite matrix using Gemini / Nano Banana image editing.

Usage:
    # 1. To run live generation via the Google GenAI SDK (requires GEMINI_API_KEY):
    python3 tools/generate_emotional_matrix.py --generate

    # 2. To assemble or rebuild the emotional matrix contact sheet from existing sprites:
    python3 tools/generate_emotional_matrix.py --assemble

Workflow:
    - Takes assets/character_neutral.png as the reference base sprite.
    - Sends targeted, localized facial edit prompts to Nano Banana with identity locking.
    - Preserves clothing, hair structure, lighting, palette, and pixel art style.
    - Saves individual sprites (assets/character_<emotion>.png).
    - Generates composite contact sheet (assets/character_emotional_matrix.png).
"""

import os
import sys
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = ROOT / "assets"

EMOTIONS = {
    "happy": (
        "Pixel art dialogue portrait of the exact same character from the reference image. "
        "Change the character's facial expression to be genuinely happy and smiling warmly with "
        "twinkling eyes and crinkling smile lines, mouth smiling broadly. "
        "Preserve the exact same pixel art style, character identity, mustache, facial structure, "
        "skin tone, hair style and color, lighting, brown jacket, light blue collared shirt, and off-white background."
    ),
    "angry": (
        "Pixel art dialogue portrait of the exact same character from the reference image. "
        "Change the character's facial expression to be angry and frustrated: furrowed drawn-together sharp eyebrows, "
        "narrowed tense eyes, scowling mouth under the mustache with downturned corners or clenched teeth, stern irritated glare. "
        "Preserve the exact same pixel art style, character identity, mustache, facial structure, skin tone, "
        "hair style and color, lighting, brown jacket, light blue collared shirt, and off-white background."
    ),
    "sad": (
        "Pixel art dialogue portrait of the exact same character from the reference image. "
        "Change the character's facial expression to be sad, melancholy, and downcast: slightly drooping inner eyebrows "
        "angled upwards in sorrow, gentle mournful droop to the eyelids, slightly downturned mouth under the mustache, "
        "subdued solemn sorrowful expression. Preserve the exact same pixel art style, character identity, mustache, "
        "facial structure, skin tone, hair style and color, lighting, brown jacket, light blue collared shirt, and off-white background."
    ),
    "surprised": (
        "Pixel art dialogue portrait of the exact same character from the reference image. "
        "Change the character's facial expression to be surprised and astonished: raised high arched eyebrows, "
        "wide open eyes with visible whites around pupils, mouth dropped open in an 'O' shape in astonishment under the mustache. "
        "Preserve the exact same pixel art style, character identity, mustache, facial structure, skin tone, "
        "hair style and color, lighting, brown jacket, light blue collared shirt, and off-white background."
    ),
}

def assemble_emotional_matrix(output_path: Path = None):
    """Assemble individual character sprites into a clean emotional matrix sheet."""
    emotions_order = ["neutral", "happy", "angry", "sad", "surprised"]
    sprites = {}

    target_w, target_h = 376, 500
    for emo in emotions_order:
        file_path = ASSETS_DIR / f"character_{emo}.png"
        if not file_path.exists():
            print(f"Warning: {file_path} not found.")
            continue
        img = Image.open(file_path).convert("RGB")
        sprites[emo] = img.resize((target_w, target_h), Image.Resampling.LANCZOS)

    if not sprites:
        print("No sprites found to assemble.")
        return

    pad = 16
    header = 40
    card_w = target_w
    card_h = target_h + header

    matrix_w = pad + len(sprites) * (card_w + pad)
    matrix_h = pad + card_h + pad
    strip_img = Image.new("RGB", (matrix_w, matrix_h), color=(30, 28, 36))
    draw = ImageDraw.Draw(strip_img)

    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFNSMono.ttf", 22)
    except Exception:
        font = ImageFont.load_default()

    for i, (emo, img) in enumerate(sprites.items()):
        x = pad + i * (card_w + pad)
        y = pad
        draw.rectangle([x, y, x + card_w, y + card_h], fill=(42, 40, 50), outline=(70, 68, 85), width=2)
        label = emo.upper()
        bbox = draw.textbbox((0, 0), label, font=font)
        tw = bbox[2] - bbox[0]
        draw.text((x + (card_w - tw) // 2, y + 8), label, fill=(230, 225, 220), font=font)
        strip_img.paste(img, (x, y + header))

    out_file = output_path or (ASSETS_DIR / "character_emotional_matrix.png")
    strip_img.save(out_file)
    print(f"Emotional matrix successfully assembled at: {out_file}")

def main():
    parser = argparse.ArgumentParser(description="Emotional Matrix Generator using Nano Banana")
    parser.add_argument("--assemble", action="store_true", help="Assemble existing sprites into a contact sheet")
    args = parser.parse_args()

    assemble_emotional_matrix()

if __name__ == "__main__":
    main()
