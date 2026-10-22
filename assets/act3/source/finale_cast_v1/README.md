# Act III finale cast — ImageGen draft v1

Generated with the built-in ImageGen tool on 2026-10-21. These are enlarged character concepts with transparent backgrounds, not runtime sprite atlases. Existing gameplay art and animation references are unchanged.

Story reference: docs/act3/ACT3_DESIGN.md, Chapter VI; scripts/act3/act3_beats.gd, the tiger/vine scenes. Both cliff tigers use the same design. Mice are one black and one white.

- tigers_concept.png: walk, run, roar; look down, look up, crouch. Intended eventual frame contract: 44×22 pixels.
- mice_concept.png: black mouse top, white mouse bottom; approach, gnaw low, gnaw raised. Intended eventual frame contract: 9×6 pixels.

The generated sheets explore the natural-colour epilogue palette, animal anatomy and acting silhouettes. They need deliberate pixel authoring and animation cleanup at the native gameplay sizes before integration.

## Tiger prompt

Use case: stylized-concept
Asset type: draft character pose sheet for Hooshang, a side-view 2D precision platformer; Act III finale, the tiger-and-lemon parable.
Primary request: design the two tigers appearing above and below the cliff as the SAME consistent tiger model, and show its acting poses for the final scenes.
Composition: wide landscape sheet, six isolated full-body tiger poses in a precise 3-column by 2-row arrangement, generous transparent gutters, no overlaps or cropping. All face screen-right in strict side profile. Top row: quiet stalking walk; stretched running gallop; planted open-mouth roar. Bottom row: standing at an edge with head looking steeply down; standing on the lower ground with head raised looking up; low tense crouch before a chase. No terrain is drawn.
Subject: a powerful believable adult tiger, long low body, strong shoulder, four anatomically coherent legs, substantial paws, expressive rounded ears, cream cheek ruff, long curling striped tail. It should feel like a wild animal that could catch the protagonist, with restrained storybook expression, no human clothing and no exaggerated mascot proportions. Recognizable consistent stripe pattern and proportions across all six poses.
Style/medium: modern detailed pixel art, soft shading, dynamic lighting, NOT 8-bit/NES. Carefully placed crisp pixel clusters, clean dark brown contour, warm amber-orange fur, near-black stripes, ivory belly/muzzle/inner legs, restrained gold sunrise highlights and cool muted brown shadows. Natural-colour painted epilogue atmosphere. No blurry painterly edges or smooth vector curves.
Scale intent: eventual gameplay frame is 44x22 pixels; the adult human is about 17 pixels tall. Present an enlarged pixel-art design study that reads clearly at this small size; strong silhouette and selective detail over tiny fur noise. This is a visual draft, not a packed production spritesheet.
Background: actual transparent alpha, no checkerboard baked into image, no drop shadows.
Constraints: same tiger identity in all six poses; show the complete tail and every visible paw; consistent side-on projection and pixel scale; clean edges; no text, captions, labels, logos, watermarks, props, humans, vines or scenery.

## Mice prompt

Use case: stylized-concept
Asset type: draft mouse character and gnawing pose sheet for Hooshang's Act III cliff-vine finale.
Primary request: a paired BLACK mouse and WHITE mouse for the tiger-and-lemon parable, clearly contrasting while belonging to the same species and art style.
Composition: landscape sheet with a precise 3-column by 2-row arrangement. Top row is the same charcoal-black mouse in three consecutive poses; bottom row is the same ivory-white mouse in the equivalent three poses. Every mouse faces screen-right in strict side profile, fully visible from tail tip to nose. Wide transparent gutters. Columns: alert low walking/approach pose, head lowered and tiny forepaws braced to gnaw a vine just ahead of the mouth, then head slightly lifted during the next gnaw with a tiny visible incisor. No vine is drawn, so each mouse remains a clean isolated asset. Subtle head/forepaw motion rather than whole-body redesign between frames.
Subject: small natural field mice, low compact pear-shaped bodies, short legs, two round ears, pointed muzzle, little dark eye with a single catchlight, fine whisker hints, long slender curved tail trailing behind. Quiet determined animals, expressive but not anthropomorphic, no clothes, no gloves, no props. Both mice share proportions. Black mouse has charcoal fur with blue-grey rim and warm grey belly; white mouse has warm ivory fur with pale grey-lavender shading; restrained muted pink inside ears, nose, feet and tail. Black silhouette readable against dark backgrounds and white silhouette readable against light backgrounds using clean contrasting outlines.
Style/medium: modern detailed pixel art, soft shading, dynamic lighting, NOT 8-bit/NES. Crisp intentional pixel clusters, thin dark contour, restrained warm sunrise highlights, soft graded colours within clean edges; natural-colour final-scene palette. No blur or vector smoothing.
Scale intent: eventual gameplay mouse frame is only 9x6 pixels in a 320x180 world, so prioritize unmistakable ear/muzzle/tail silhouettes and strong black-vs-white distinction. This sheet is an enlarged concept draft for later sprite authoring, not a production atlas; avoid miniature noisy fur detail.
Background: actual transparent alpha, no checkerboard baked into image, no ground or drop shadows.
Constraints: consistent individual mouse across its row, consistent body size across all six cells, identical side-view projection and pixel scale, no text, labels, captions, logos, watermarks, tigers, humans, food, vines or scenery.

