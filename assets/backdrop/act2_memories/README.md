# Act 2 memory paintings

Generated with the built-in image_gen tool. Exact final prompts are preserved
in `prompts.json`; the untouched selected outputs live in `source/`:
`arrest.png`, `corridor.png`, `mother.png`, `rain.png`.

These are non-tiled, full-screen cinematic paintings, using the project's
set-piece exception for painterly artwork. They are not gameplay tiles or
replacement character sprites. The real memory shows seventeen-year-old
cousins, distinct from the child actors in the invented school-prison.

`MemoryTableau.tscn` displays each image within the native 320×180 viewport.
Only its painting TextureRect uses linear downsampling; the game viewport and
all gameplay art retain nearest filtering. Source bitmaps are never resized or
cropped by an export script. The existing typeset Persian first line overlays
the blank rainy wall, preserving spelling independently of generated imagery.
A subdued procedural rain overlay supplies motion during that flash.

Arrest and corridor first appear as short silent flashes. Arrest returns for
the officer's exchange, then the mother appears for her line. The rain image
holds briefly before the scene returns to the carpet. All holds are skippable;
the existing dialogue resource remains the author's verbatim text.
