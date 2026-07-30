@tool
## LDtk level post-import hook (see STYLE_GUIDE.md §9), wired as the .ldtk
## import's `level_post_import`.
##
## Its job: neutralise the importer's IntGrid "-values" debug layers.
##
## For an IntGrid layer with NO tileset assigned — a purely SEMANTIC layer,
## like this project's `Collision` layer (Solid / OneWay / Hazard /
## UnderworldTrigger) — the addon builds a TileMapLayer of flat colour
## swatches taken from each value's editor colour, and it does so
## UNCONDITIONALLY: see the `not has_tileset or ...` branch in
## addons/ldtk-importer/src/layer.gd. The `integer_grid_tilesets` import
## option does NOT turn this off, so those cells otherwise show up in-game as
## solid coloured rectangles (Solid is #6B7280 — a grey box) that also collide,
## because ldtk_tileset_post_import.gd gives every tile a collision shape.
##
## Those swatches are an editor visualisation, never art. Hide them and take
## them out of the physics world. Real geometry lives on IntGrid layers that
## DO have a tileset (here `Collisions`, drawn with the brick auto-tiles),
## which the addon emits as an ordinary tile layer and this leaves untouched.
##
## NOTE: this means painting on a tileset-less semantic layer now has no
## effect in-game at all. Giving `OneWay` / `Hazard` / `UnderworldTrigger`
## real behaviour is a separate job — read the IntGrid values and build proper
## nodes for them, rather than relying on these swatch tiles.

const VALUES_LAYER_SUFFIX := "-values"


func post_import(level: LDTKLevel) -> LDTKLevel:
	for child in level.get_children():
		if child is TileMapLayer and child.name.ends_with(VALUES_LAYER_SUFFIX):
			var layer: TileMapLayer = child
			layer.visible = false
			layer.collision_enabled = false
	return level
