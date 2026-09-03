#!/usr/bin/env python3
"""Generate a 9-frame expression sub-matrix for each base emotion of Hooshang.

Mouth states:
  0: mouth_closed
  1: mouth_mid_talk
  2: mouth_talk

Eye states:
  0: eyes_open
  1: eyes_mid_blink
  2: eyes_closed

Total frames per emotion: 3 x 3 = 9 frames.
Total for 5 emotions (neutral, happy, angry, sad, surprised): 45 frames.
"""

import os
import shutil
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = ROOT / "assets"
SPRITES_DIR = ROOT / "sprites" / "hooshang"
ASSETS_SPRITES_DIR = ASSETS_DIR / "sprites" / "hooshang"
BRAIN_DIR = Path("/Users/ari/.gemini/antigravity/brain/6a91f23e-28a6-4cdd-97a4-d01d5bc93226")

SPRITES_DIR.mkdir(parents=True, exist_ok=True)
ASSETS_SPRITES_DIR.mkdir(parents=True, exist_ok=True)

EMOTIONS = ["neutral", "happy", "angry", "sad", "surprised"]

MOUTH_STATES = ["mouth_closed", "mouth_mid_talk", "mouth_talk"]
EYE_STATES = ["eyes_open", "eyes_mid_blink", "eyes_closed"]

# Distinctive facial coordinates and colors per emotion
EMOTION_CONFIGS = {
    "neutral": {
        "left_eye": (102, 198, 156, 234),
        "right_eye": (218, 198, 272, 234),
        "skin_tone": (196, 142, 107),
        "lash_color": (36, 28, 38),
        "crease_color": (150, 105, 78),
        "cx": 188, "lip_y": 338,
        "cavity": (38, 14, 16), "teeth": (215, 210, 210), "lip": (50, 26, 22),
        "happy_lid_curve": False,
    },
    "happy": {
        "left_eye": (102, 196, 156, 232),
        "right_eye": (218, 196, 272, 232),
        "skin_tone": (202, 146, 112),
        "lash_color": (38, 28, 38),
        "crease_color": (155, 110, 82),
        "cx": 188, "lip_y": 332,
        "cavity": (48, 16, 20), "teeth": (225, 220, 220), "lip": (58, 28, 24),
        "happy_lid_curve": True,
    },
    "angry": {
        "left_eye": (104, 200, 158, 236),
        "right_eye": (218, 200, 272, 236),
        "skin_tone": (190, 136, 102),
        "lash_color": (32, 22, 32),
        "crease_color": (145, 98, 72),
        "cx": 188, "lip_y": 340,
        "cavity": (35, 10, 12), "teeth": (200, 195, 195), "lip": (45, 20, 18),
        "happy_lid_curve": False,
    },
    "sad": {
        "left_eye": (102, 200, 156, 238),
        "right_eye": (218, 200, 272, 238),
        "skin_tone": (192, 138, 105),
        "lash_color": (34, 26, 36),
        "crease_color": (148, 102, 75),
        "cx": 188, "lip_y": 344,
        "cavity": (36, 12, 14), "teeth": (205, 200, 200), "lip": (48, 24, 20),
        "happy_lid_curve": False,
    },
    "surprised": {
        "left_eye": (98, 192, 158, 236),
        "right_eye": (216, 192, 276, 236),
        "skin_tone": (196, 142, 107),
        "lash_color": (35, 25, 35),
        "crease_color": (150, 105, 78),
        "cx": 188, "lip_y": 342,
        "cavity": (32, 10, 12), "teeth": (210, 205, 205), "lip": (46, 22, 18),
        "happy_lid_curve": False,
    }
}

def apply_eye_state(img: Image.Image, emo: str, state: str) -> Image.Image:
    if state == "eyes_open":
        return img.copy()

    cfg = EMOTION_CONFIGS[emo]
    out = img.copy()
    draw = ImageDraw.Draw(out)

    skin = cfg["skin_tone"]
    lash = cfg["lash_color"]
    crease = cfg["crease_color"]
    happy = cfg["happy_lid_curve"]

    for (x0, y0, x1, y1) in [cfg["left_eye"], cfg["right_eye"]]:
        ew = x1 - x0
        eh = y1 - y0

        if state == "eyes_mid_blink":
            # Cover top 60% of eye opening with eyelid
            draw.rectangle([x0, y0, x1, y0 + int(eh * 0.62)], fill=skin)
            # Eyelash line
            draw.line([(x0, y0 + int(eh * 0.62)), (x1, y0 + int(eh * 0.62))], fill=lash, width=3)
            # Crease line
            draw.line([(x0 + 4, y0 + 2), (x1 - 4, y0 + 2)], fill=crease, width=2)
        elif state == "eyes_closed":
            # Cover entire eye opening
            draw.rectangle([x0, y0 + 1, x1, y1 - 1], fill=skin)
            if happy:
                # Upward smiling crescent arc
                draw.arc([x0, y0 + 4, x1, y1 + 4], start=200, end=340, fill=lash, width=3)
                draw.line([(x0 + 4, y0 + 2), (x1 - 4, y0 + 2)], fill=crease, width=2)
            else:
                # Downward gentle resting arc
                draw.arc([x0 - 2, y1 - 18, x1 + 2, y1 + 2], start=15, end=165, fill=lash, width=3)
                draw.line([(x0 + 4, y0 + 4), (x1 - 4, y0 + 4)], fill=crease, width=2)

    return out

def apply_mouth_state(img: Image.Image, emo: str, state: str) -> Image.Image:
    if state == "mouth_closed":
        return img.copy()

    cfg = EMOTION_CONFIGS[emo]
    out = img.copy()
    draw = ImageDraw.Draw(out)

    cx = cfg["cx"]
    lip_y = cfg["lip_y"]
    cavity = cfg["cavity"]
    teeth = cfg["teeth"]
    lip = cfg["lip"]

    if state == "mouth_mid_talk":
        if emo == "surprised":
            mw, mh = 26, 24
            draw.ellipse([cx - mw, lip_y - 4, cx + mw, lip_y + mh], fill=cavity, outline=lip, width=2)
            draw.rectangle([cx - mw + 6, lip_y - 2, cx + mw - 6, lip_y + 4], fill=teeth)
        elif emo == "happy":
            mw, mh = 42, 18
            draw.ellipse([cx - mw, lip_y - 5, cx + mw, lip_y + mh], fill=cavity, outline=lip, width=2)
            draw.rectangle([cx - mw + 8, lip_y - 4, cx + mw - 8, lip_y + 4], fill=teeth)
        elif emo == "angry":
            mw, mh = 36, 15
            draw.rectangle([cx - mw, lip_y - 2, cx + mw, lip_y + mh], fill=cavity, outline=lip, width=2)
            draw.rectangle([cx - mw + 6, lip_y - 1, cx + mw - 6, lip_y + 5], fill=teeth)
        else: # neutral, sad
            mw, mh = 36, 14
            draw.ellipse([cx - mw, lip_y - 4, cx + mw, lip_y + mh], fill=cavity, outline=lip, width=2)
            draw.rectangle([cx - mw + 8, lip_y - 3, cx + mw - 8, lip_y + 3], fill=teeth)

    elif state == "mouth_talk":
        if emo == "surprised":
            # Deep 'O' gasp
            mw, mh = 34, 38
            draw.ellipse([cx - mw, lip_y - 6, cx + mw, lip_y + mh], fill=cavity, outline=lip, width=3)
            draw.rectangle([cx - mw + 8, lip_y - 4, cx + mw - 8, lip_y + 5], fill=teeth)
            draw.arc([cx - mw + 10, lip_y + 14, cx + mw - 10, lip_y + mh - 4], start=0, end=180, fill=(160, 55, 60), width=3)
        elif emo == "happy":
            mw, mh = 48, 28
            draw.ellipse([cx - mw, lip_y - 6, cx + mw, lip_y + mh], fill=cavity, outline=lip, width=2)
            draw.rectangle([cx - mw + 10, lip_y - 5, cx + mw - 10, lip_y + 5], fill=teeth)
            draw.arc([cx - mw + 14, lip_y + 8, cx + mw - 14, lip_y + mh - 2], start=0, end=180, fill=(170, 60, 65), width=3)
        elif emo == "angry":
            mw, mh = 44, 24
            draw.rectangle([cx - mw, lip_y - 4, cx + mw, lip_y + mh], fill=cavity, outline=lip, width=2)
            # Clenched upper and lower teeth
            draw.rectangle([cx - mw + 8, lip_y - 3, cx + mw - 8, lip_y + 5], fill=teeth)
            draw.rectangle([cx - mw + 10, lip_y + mh - 7, cx + mw - 10, lip_y + mh - 1], fill=teeth)
        else: # neutral, sad
            mw, mh = 42, 26
            draw.ellipse([cx - mw, lip_y - 6, cx + mw, lip_y + mh], fill=cavity, outline=lip, width=2)
            draw.rectangle([cx - mw + 10, lip_y - 5, cx + mw - 10, lip_y + 4], fill=teeth)
            draw.arc([cx - mw + 12, lip_y + 7, cx + mw - 12, lip_y + mh - 3], start=0, end=180, fill=(160, 55, 60), width=3)

    return out

def build_composite_submatrix(frames_dict: dict, emo: str) -> Image.Image:
    """Build a 3x3 composite sheet with clear headers for an emotion."""
    pad = 16
    header_h = 44
    cell_w, cell_h = 376, 500
    sub_w = pad + 3 * (cell_w + pad)
    sub_h = 70 + pad + 3 * (cell_h + header_h + pad)

    sheet = Image.new("RGB", (sub_w, sub_h), color=(26, 24, 32))
    draw = ImageDraw.Draw(sheet)

    try:
        font_title = ImageFont.truetype("/System/Library/Fonts/SFNSMono.ttf", 26)
        font_label = ImageFont.truetype("/System/Library/Fonts/SFNSMono.ttf", 18)
    except Exception:
        font_title = ImageFont.load_default()
        font_label = ImageFont.load_default()

    # Title header
    title = f"HOOSHANG EMOTION SUB-MATRIX: {emo.upper()} (3x3 ANIMATION GRID)"
    bbox = draw.textbbox((0, 0), title, font=font_title)
    tw = bbox[2] - bbox[0]
    draw.text(((sub_w - tw) // 2, 22), title, fill=(255, 215, 90), font=font_title)

    for r, mouth in enumerate(MOUTH_STATES):
        for c, eye in enumerate(EYE_STATES):
            frame_num = r * 3 + c + 1
            key = f"{emo}_matrix_{frame_num:02d}"
            img = frames_dict[key]

            x = pad + c * (cell_w + pad)
            y = 70 + pad + r * (cell_h + header_h + pad)

            # Card frame
            draw.rectangle([x, y, x + cell_w, y + cell_h + header_h], fill=(38, 36, 46), outline=(65, 60, 78), width=2)

            # Header text: e.g. #01: CLOSED / OPEN
            short_m = mouth.replace("mouth_", "").upper()
            short_e = eye.replace("eyes_", "").upper()
            label = f"#{frame_num:02d} | M:{short_m} | E:{short_e}"
            lbbox = draw.textbbox((0, 0), label, font=font_label)
            ltw = lbbox[2] - lbbox[0]
            draw.text((x + (cell_w - ltw) // 2, y + 12), label, fill=(220, 220, 230), font=font_label)

            # Paste image
            sheet.paste(img, (x, y + header_h))

    return sheet

def main():
    print("=== Generating Hooshang 9-Frame Expression Sub-Matrices ===")
    all_frames = {}

    for emo in EMOTIONS:
        base_path = ASSETS_DIR / f"character_{emo}.png"
        if not base_path.exists():
            print(f"Error: Missing base portrait {base_path}")
            continue

        base_img = Image.open(base_path).convert("RGB")
        print(f"Processing emotion: {emo}...")

        frame_count = 1
        for r, mouth in enumerate(MOUTH_STATES):
            for c, eye in enumerate(EYE_STATES):
                # 1. Apply eye state
                eye_frame = apply_eye_state(base_img, emo, eye)
                # 2. Apply mouth state
                final_frame = apply_mouth_state(eye_frame, emo, mouth)

                frame_name = f"{emo}_matrix_{frame_count:02d}"
                all_frames[frame_name] = final_frame

                # Save systematically named PNG
                out_path1 = SPRITES_DIR / f"{frame_name}.png"
                out_path2 = ASSETS_SPRITES_DIR / f"{frame_name}.png"
                final_frame.save(out_path1)
                final_frame.save(out_path2)

                # Save descriptive alias
                desc_path = SPRITES_DIR / f"{emo}_{mouth}_{eye}.png"
                final_frame.save(desc_path)

                print(f"  Frame {frame_count:02d}/09: {frame_name}.png (Mouth: {mouth}, Eyes: {eye})")
                frame_count += 1

        # Build 3x3 composite sub-matrix
        sub_matrix_img = build_composite_submatrix(all_frames, emo)
        sub_matrix_path = SPRITES_DIR / f"{emo}_sub_matrix.png"
        sub_matrix_img.save(sub_matrix_path)
        sub_matrix_img.save(ASSETS_SPRITES_DIR / f"{emo}_sub_matrix.png")
        # Also copy to brain artifact dir
        sub_matrix_img.save(BRAIN_DIR / f"{emo}_sub_matrix.png")
        print(f"  -> Saved 3x3 sub-matrix sheet to {sub_matrix_path}")

    # Build Master Summary Sheet (comparing samples across all 5 emotions)
    print("\nBuilding Master Summary Composite...")
    summary_w = 16 + 5 * (376 + 16)
    summary_h = 70 + 16 + 3 * (500 + 44 + 16)
    summary_img = Image.new("RGB", (summary_w, summary_h), color=(20, 18, 26))
    sdraw = ImageDraw.Draw(summary_img)

    try:
        sfont_title = ImageFont.truetype("/System/Library/Fonts/SFNSMono.ttf", 28)
        sfont_label = ImageFont.truetype("/System/Library/Fonts/SFNSMono.ttf", 18)
    except Exception:
        sfont_title = ImageFont.load_default()
        sfont_label = ImageFont.load_default()

    stitle = "HOOSHANG 5-EMOTION SUB-MATRIX MASTER SHOWCASE"
    sbbox = sdraw.textbbox((0, 0), stitle, font=sfont_title)
    sdraw.text(((summary_w - (sbbox[2] - sbbox[0])) // 2, 22), stitle, fill=(255, 220, 100), font=sfont_title)

    # Pick 3 key frames per emotion:
    # Row 0: Rest (Closed, Open - frame 01)
    # Row 1: Blink (Closed, Closed - frame 03)
    # Row 2: Speak (Talk, Open - frame 07)
    sample_picks = [
        (1, "REST (CLOSED / OPEN)"),
        (3, "BLINK (CLOSED / CLOSED)"),
        (7, "SPEAK (TALK / OPEN)"),
    ]

    for c, emo in enumerate(EMOTIONS):
        for r, (frame_idx, row_desc) in enumerate(sample_picks):
            key = f"{emo}_matrix_{frame_idx:02d}"
            img = all_frames[key]
            x = 16 + c * (376 + 16)
            y = 70 + 16 + r * (500 + 44 + 16)

            sdraw.rectangle([x, y, x + 376, y + 544], fill=(32, 30, 40), outline=(60, 56, 72), width=2)
            label = f"{emo.upper()}: {row_desc}"
            lbbox = sdraw.textbbox((0, 0), label, font=sfont_label)
            sdraw.text((x + (376 - (lbbox[2] - lbbox[0])) // 2, y + 12), label, fill=(230, 225, 230), font=sfont_label)
            summary_img.paste(img, (x, y + 44))

    summary_path = SPRITES_DIR / "hooshang_emotional_submatrix_summary.png"
    summary_img.save(summary_path)
    summary_img.save(ASSETS_SPRITES_DIR / "hooshang_emotional_submatrix_summary.png")
    summary_img.save(BRAIN_DIR / "hooshang_emotional_submatrix_summary.png")
    print(f"Master summary saved to {summary_path} and brain artifact directory.")

    print("\nAll 45 frames and composite sheets generated successfully!")

if __name__ == "__main__":
    main()
