#!/usr/bin/env python3
"""Index the talking-portrait loops: which frame is silence, which are speech,
which is the blink.

The sheets in assets/portraits/loops/ are seven-frame talking cycles generated
from one base portrait (see the commit that added them). They are ART; this
turns them into something the dialogue box can DRIVE, by writing the frame roles
into their manifest:

    rest   the silent pose — mouth closed, eyes open. Always frame 0, because
           frame 0 is the untouched source still the loop was generated from.
    talk   the frames to cycle while words are appearing.
    blink  the one frame with his eyes shut, or absent if he has none.

WHY THE ROLES ARE COMPUTED HERE AND NOT AT RUNTIME. The generator that made
these loops animated the whole face at once — eyes and mouth move together in
every frame, and nothing in the image says which change is which. Working that
out means measuring, and measuring on every line of dialogue would be absurd; it
also would not be reproducible, since a re-generated sheet could land its blink
on a different frame. So it is measured ONCE, here, and the answer is data.

HOW THE BLINK IS FOUND: by EDGE ENERGY in the eye band, not by brightness or by
difference from frame 0. A closed lid removes the pupil, the lash line and the
iris edge all at once, so the eye region goes smooth; brightness barely moves,
and plain difference-from-frame-0 cannot tell a blink from a raised eyebrow —
measured, both peak on the same frames. A frame only counts as the blink if its
eye band is meaningfully smoother than frame 0's (BLINK_DROP), so a face that
never shuts its eyes reports no blink rather than a false one.

THE BLINK FRAME IS EXCLUDED FROM `talk`. That is what keeps the box's existing
contract intact: the mouth is driven by the typewriter and the blink runs on its
own clock, so he cannot blink only-while-speaking, and a held line still blinks.

Re-run after regenerating any sheet:  python3 tools/gen_portrait_loops.py
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOOPS = os.path.join(ROOT, "assets/portraits/loops")

## The bands the face actually moves in, measured off the sheets themselves:
## activity peaks at y 24-64 (brows and eyes) and y 96-140 (mouth). These are
## the eye band narrowed horizontally to the face, so the hair edges — which
## move with nothing — cannot vote.
##
## THIS IS HOOSHANG'S FACE, and it is only the default. It is where HIS eyes
## are, in a frame he fills bare-headed. Rumi wears a turban and sits lower:
## measured off his own blink, his eyes are at y 98-124, and read in the band
## below they would be missed entirely — the blink would go unfound and his
## faces would never shut their eyes, silently. So an entry may carry its own
## `eye` band, as [y0, y1, x0, x1], and gen_rumi_loops.py writes one.
EYE = [40, 68, 78, 180]
## How much smoother than frame 0 the eye band has to be to count as shut.
BLINK_DROP = 0.10
## Frames per second the box plays a talking cycle at.
FPS = 8


def eye_edge(frame, eye):
    """Edge energy in the eye band: high with the eyes open, low with them shut."""
    b = frame[eye[0]:eye[1], eye[2]:eye[3]]
    return float(np.abs(np.diff(b, axis=0)).mean() + np.abs(np.diff(b, axis=1)).mean())


def roles(path, frames, eye):
    sheet = np.asarray(Image.open(path).convert("L"), dtype=np.float64)
    w = sheet.shape[1] // frames
    energy = [eye_edge(sheet[:, i * w:(i + 1) * w], eye) for i in range(frames)]
    shut = int(min(range(frames), key=lambda i: energy[i]))
    blink = shut if energy[shut] < energy[0] * (1.0 - BLINK_DROP) else None
    # Never frame 0 in `talk`: frame 0 is the closed mouth and it means silence,
    # so picking it mid-word reads as a stutter. Never the blink either — that
    # belongs to its own clock.
    talk = [i for i in range(1, frames) if i != blink]
    return blink, talk, energy


def main():
    man_path = os.path.join(LOOPS, "manifest.json")
    man = json.load(open(man_path))
    for key in sorted(man):
        entry = man[key]
        path = os.path.join(LOOPS, entry["sheet"])
        blink, talk, energy = roles(path, int(entry["frames"]),
                                    entry.get("eye", EYE))
        entry["rest"] = 0
        entry["talk"] = talk
        if blink is None:
            entry.pop("blink", None)
        else:
            entry["blink"] = blink
        entry["fps"] = FPS
        print("  %-22s blink=%-5s talk=%s" % (key, blink, talk))
        print("  %-22s eye edge: %s" % ("", " ".join("%.1f" % e for e in energy)))
    json.dump(man, open(man_path, "w"), indent=2)
    print("\nwrote %s" % os.path.relpath(man_path, ROOT))


if __name__ == "__main__":
    main()
