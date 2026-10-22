# Lemon loading illustration

Created with built-in ImageGen on 2026-10-21 from the user's lemon-poster reference. The final direction is deliberately simple, nostalgic watercolor: broad yellow/ochre washes, a green leaf, faded blue border and tiny folk-flower corners. This is full-resolution UI artwork, not a gameplay tile. `lemon_watercolor_leaf.png` is the selected version.

The text is separate in `scenes/ui/loading/LemonLoadingCard.tscn`, revealing in this order:

1. WHEN LIFE GIVES YOU A LEMON — upper left.
2. YOU MUST EAT THE LEMON — lower right.
3. ALL OF IT INCLUDING THE SKIN — smaller, underneath.

Patrick Hand provides the loose handwritten lettering, following the original poster. It is distributed under the SIL Open Font License; font and license are in `assets/fonts/patrick_hand/`. Source: https://github.com/google/fonts/tree/main/ofl/patrickhand

`Screen.load_scene_with_card` loads resources in the background while this card plays, then instantiates the world beneath the final fade. The title menu opts into it for new/continued/practice/exploration launches; Act I → II and Act II → III also use it. Ordinary room slides and deaths retain their existing flow. Direct `Screen.load_scene` remains synchronous for developer scenes and tests. Reading/reveal durations are editable on the prefab.

## Base ImageGen prompt

The final leaf-restoration edit is recorded in `leaf_edit_prompt.md`.

A VERY SIMPLE, low-detail nostalgic watercolor loading-screen illustration for a Persian-inspired game, wide 16:9. Use the supplied little handmade lemon poster as the simplicity reference. One huge lopsided golden lemon on pale warm ivory paper, with a tiny crooked dark green stem and NO leaf. Paint the entire lemon using only THREE broad watery brush shapes: pale golden yellow base, a loose ochre wash on the left, one pale untouched highlight on the upper right. A few irregular feathered edges. Flat naïve folk illustration, like an old 1970s children's picture book from Iran. Tender and slightly funny. Deliberately unpolished and loosely painted, no realism or dimensional fruit rendering. Almost no texture inside the fruit; absolutely NO rind pores, speckles, mottling, leaf veins, fine brush marks, or busy paper grain. No precise outlines.
One very thin uneven faded blue border and four extremely small simple dot-flower corner marks. Abundant empty paper at TOP LEFT and BOTTOM RIGHT for text that the game will animate separately. Lemon centered x52% y50%, width42% height75%. Muted sun-faded ochre, warm lemon yellow, ivory, a little faded blue. Quiet, simple, old-school handmade watercolor. The result must be DRAMATICALLY LESS DETAILED than polished watercolor botanical art. NO TEXT or lettering of any kind, no mockup, no photographic shadows. Full opaque ivory-paper background.
