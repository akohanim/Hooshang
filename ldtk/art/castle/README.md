# Act 2 castle tiles

Imported from the supplied `castle_tileset.zip`. Both PNGs are unchanged.

- `castle-01.png` (224×192): banners, windows and trim; LDtk tileset `Act2CastleDecor`.
- `castle-02.png` (608×416): masonry and wall patterns; LDtk tileset `Act2CastleMasonry`.

Open `ldtk/hooshang_act2.ldtk` and select a castle layer:

- **CastleTerrain**: solid masonry. Each painted 8×8 cell has square collision.
- **CastleBackground**: masonry scenery behind the player, without collision.
- **CastleDecor**: banners, windows and trim behind the player, without collision.

The sheets retain their native dimensions on the game's 8px grid. Select a
rectangle of cells in the tileset palette to paint a larger architectural piece;
the layers have a 32px guide grid for the larger repeating blocks. Transparent
parts of a partly painted terrain cell still use that cell's full collision box,
so use the scenery layers for windows, arches and ornamental silhouettes.

Existing terrain and room layouts are unchanged. Castle layers start empty.

To repeat the setup, close LDtk/Godot and run:

    python3 tools/ldtk_add_castle_tileset.py --archive /path/to/castle_tileset.zip --apply

Then import the project in Godot. The setup is idempotent. Import/physics check:

    /Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/castle_tileset_test.tscn
