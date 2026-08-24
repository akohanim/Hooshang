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

## The layer the world's geometry is painted on, and the atlas coordinate of the
## ceiling PANEL tile on its sheet. The sheet's tile order is fixed and
## documented in tools/gen_bricks_8px.py ("Order on the sheet IS the tile id the
## rules use, so do not reorder") — this is tile 5.
const GEOMETRY_LAYER := "Collisions"
## Paintable thought-hazard tiles — pass-through (no world collision), and the
## kill check lives in ldtk_world.gd, not in physics.
const THOUGHT_LAYER := "ThoughtHazards"
## The panel tiles, and the emission each one wears. Two, because the ceiling is
## painted in two orientations — `ceiling_flor` is a surface seen edge on and
## `ceiling` is the room's own roof seen from below — and their panels sit at
## different heights in the cell, so one glow cannot serve both.
const PANEL_TILES := {
	Vector2i(5, 0): preload("res://assets/props/ceiling/ceiling_tile_glow.png"),
	Vector2i(7, 0): preload("res://assets/props/ceiling/ceiling_over_glow.png"),
}

## What a painted panel emits.
##
## A TILE CANNOT GLOW. `CanvasModulate` is 0.05 in Act I and multiplies every
## CanvasItem, so the panel drawn into the tile arrives at 5% of what was drawn —
## the trap SunShaft, WallPattern and CeilingPanel all document. Painting the
## ceiling therefore gets you the architecture and nothing else, unless something
## hangs a light on it, and hanging one by hand on every cell of every painted
## run is not a thing anybody would keep up. So the import does it.
##
## Two lights per cell, because they are two different jobs: the PANEL is how
## bright the fitting looks, drawn to the shape of the tile's own panel, and the
## POOL is the light that actually falls into the room under it. The pool is kept
## deliberately weak — panels land every third cell, so a run of them stacks, and
## anything stronger turns a corridor into an even wash with nothing dark left.
const POOL_TEXTURE := preload("res://assets/light_radial.png")
const PANEL_COLOR := Color(0.83, 0.9, 0.95)
const PANEL_ENERGY := 1.4
const POOL_ENERGY := 0.5
## 64px of radius per 1.0 — see LIGHTING.md.
const POOL_SCALE := 1.0
## How far below the cell the pool is centred. A ceiling lights the room beneath
## it, so the pool hangs under the tile rather than sitting inside it.
const POOL_DROP := 18.0


## Draw bands, applied by LDtk layer name so the ordering is explicit rather
## than an accident of sibling order: -1 is scenery the player walks IN FRONT of,
## 0 is the playable area (tiles, entities, the player), 1 is scenery the player
## walks BEHIND.
const Z_BANDS := {"Background": -1, "Foreground": 1}


func post_import(level: LDTKLevel) -> LDTKLevel:
	for child in level.get_children():
		if child is not TileMapLayer:
			continue
		var layer: TileMapLayer = child
		if layer.name.ends_with(VALUES_LAYER_SUFFIX):
			layer.visible = false
			layer.collision_enabled = false
		elif layer.name == THOUGHT_LAYER:
			layer.collision_enabled = false
			var mat := CanvasItemMaterial.new()
			mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
			layer.material = mat
		elif Z_BANDS.has(layer.name):
			layer.z_index = Z_BANDS[layer.name]
		if layer.name == GEOMETRY_LAYER:
			_light_panels(level, layer)
	return level


## Hang a light on every painted ceiling panel in this level.
func _light_panels(level: LDTKLevel, layer: TileMapLayer) -> void:
	var cells: Array[Vector2i] = []
	for cell in layer.get_used_cells():
		if PANEL_TILES.has(layer.get_cell_atlas_coords(cell)):
			cells.append(cell)
	if cells.is_empty():
		return
	var holder := Node2D.new()
	holder.name = "CeilingGlow"
	level.add_child(holder)
	holder.owner = level
	for cell in cells:
		# In LEVEL space, not global: nothing is in a tree yet at import time, so
		# a global transform would be whatever the level happens to sit at, which
		# during import is the origin. The layer's own transform is the only
		# thing between the two.
		var at: Vector2 = layer.transform * layer.map_to_local(cell)
		var glow: Texture2D = PANEL_TILES[layer.get_cell_atlas_coords(cell)]
		_add_light(holder, level, at, glow, PANEL_ENERGY, 1.0)
		_add_light(holder, level, at + Vector2(0.0, POOL_DROP),
			POOL_TEXTURE, POOL_ENERGY, POOL_SCALE)


func _add_light(holder: Node2D, level: LDTKLevel, at: Vector2,
		texture: Texture2D, energy: float, scale: float) -> void:
	var light := PointLight2D.new()
	light.texture = texture
	light.texture_scale = scale
	light.color = PANEL_COLOR
	light.energy = energy
	light.position = at
	holder.add_child(light)
	light.owner = level
