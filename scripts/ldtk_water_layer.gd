class_name WaterLayer
extends TileMapLayer
## Runtime driver for the paintable `Water` tiles (see STYLE_GUIDE.md §9).
## Attached at import time (ldtk_level_post_import.gd) to every Water
## TileMapLayer, the same way ThoughtHazardLayer is swapped onto its own node
## — a script attached at import time survives being packed into the saved
## .scn; logic added in the post-import hook itself would not.
##
## TWO JOBS:
##
##  1. The surface shimmer — the TOP/CORNER columns' own animation, driven
##     per cell on its OWN hashed clock, same reasoning ThoughtHazardLayer's
##     own header gives for why this cannot be Godot's built-in tile
##     animation (one shared clock per atlas tile would pulse every painted
##     cell in lockstep, reading as a grid rather than many small patches of
##     living water).
##
##  2. The depth gradient — retargeting a "fill" cell to "fill_deep" once it
##     is far enough below the nearest opening above it. This is the one
##     thing Pond's own resizable box got for free just by knowing "row 0 is
##     the surface, everything below is body" — an LDtk auto-rule has no
##     equivalent, since it only ever sees its IMMEDIATE neighbours' IntGrid
##     values, never "how far down am I". So it is measured here, once, at
##     room entry, by walking upward from each fill cell.
##
## REFRACTED, same as Pond's own water — `_ready()` assigns
## assets/shaders/water_distortion.gdshader directly as this layer's own
## `material` (a TileMapLayer is one CanvasItem, so unlike Pond's many small
## Sprite2D tiles there is no per-child `use_parent_material` to set up).
##
## NO FISH HERE, DELIBERATELY — unlike Pond, which scatters a few. Painted
## water is meant for irregular, often small or branching shapes (this is
## also the layer with no floor of its own, just whatever is directly below
## the lowest painted row), and a per-region fish scatter here read as
## cluttered/arbitrary in a way it does not in a Pond's own clean box. Fish
## are still purely Pond's thing — see scenes/props/zones/pond.gd.
##
## The player never queries this layer directly — scripts/ldtk_world.gd does
## that (see its `_in_water_tile()`), the same way it already owns the
## ThoughtHazards kill check; this script only owns what gets DRAWN.
##
## Pond (scenes/props/zones/pond.gd) is not replaced by this — the two stay
## side by side, one for a simple dragged-and-resized rectangle, this one for
## an irregular shape painted cell by cell with a real edge where it meets a
## bank. Both end up calling the exact same Player.enter_swim()/exit_swim().

enum Tile { FILL, TOP, LEFT, CORNER, FILL_DEEP }
## Only the surface-facing tiles animate; fill/fill_deep/left repeat the same
## drawn frame on every row of the sheet (see gen_act2_water_tiles.py) so the
## sheet stays one uniform grid, but there is nothing to re-pick for them.
const ANIMATED_TILES := [Tile.TOP, Tile.CORNER]
const FRAMES := 3
const FRAME_TIME := 0.3
## A "fill" cell counts as deep once this many painted cells separate it from
## the nearest non-water cell above it. 0 never happens for a genuine fill
## cell — its own immediate north is water, or the auto-rule would have made
## it TOP/CORNER instead — so this is really "1 row under the surface stays
## shallow, 2 or more goes deep".
const DEEP_AT := 2

const UP := Vector2i(0, -1)

## Refraction — same shader Pond's own water shares across its tile sprites
## (see the shader's own header, and pond.gd's note on why this needs to be a
## shader at all). A TileMapLayer is one CanvasItem already, so this is set
## directly as `self.material` in _ready() — no per-tile `use_parent_material`
## dance needed, unlike Pond's many small Sprite2D children.
const WATER_SHADER := preload("res://assets/shaders/water_distortion.gdshader")


class _Cell:
	var coord: Vector2i
	var source_id: int
	var col: int           ## tile type — fixed after _ready() (see the depth pass)
	## The auto-rule's own flipX/flipY, carried through every rewrite below.
	## set_cell()'s `alternative_tile` argument DEFAULTS TO 0, which is the
	## untransformed tile — so re-drawing a cell without passing this back
	## silently throws the mirroring away. See _ready()'s own note.
	var alt := 0
	var clock := 0.0
	var phase := 0.0
	var frame := -1          ## last atlas row actually drawn; -1 forces the first set_cell


var _cells: Array[_Cell] = []


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	material = mat

	var used := get_used_cells()
	var painted := {}
	for coord in used:
		painted[coord] = true

	for coord in used:
		var cell := _Cell.new()
		cell.coord = coord
		cell.source_id = get_cell_source_id(coord)
		cell.col = get_cell_atlas_coords(coord).x
		# READ THE MIRRORING BACK BEFORE ANY set_cell BELOW OVERWRITES IT.
		# Only four tiles are ever drawn (fill/top/left/corner) and the auto-
		# rules build the other edges and corners by MIRRORING those — the
		# right bank is `left` flipped X, the floor is `top` flipped Y. Every
		# rewrite this script makes, both the depth pass here and the shimmer
		# in _process, has to hand that transform back or the cell silently
		# reverts to the unmirrored drawing.
		#
		# Shipped once, and it was reported from play as "horizontal and
		# vertical lines that shouldn't be there": the tiles still drew their
		# contact line and their shimmer, but on the edge they were DRAWN
		# for rather than the edge they were placed against — so the right
		# bank's line landed a full cell inside the water and the floor's
		# landed a cell above it, both of them hanging in open water with
		# nothing to be the contact line OF.
		cell.alt = get_cell_alternative_tile(coord)
		if cell.col == Tile.FILL and _depth_below_surface(coord, painted) >= DEEP_AT:
			cell.col = Tile.FILL_DEEP
		if cell.col in ANIMATED_TILES:
			# Hashed from the cell, not randf() — two shimmering cells should
			# not pulse in lockstep, and the same layout should look the same
			# on every visit (ThoughtHazardLayer's own note on this).
			cell.phase = _hash01(coord.x, coord.y) * FRAMES * FRAME_TIME
			_cells.append(cell)
		else:
			set_cell(coord, cell.source_id, Vector2i(cell.col, 0), cell.alt)
	set_process(not _cells.is_empty())


func _process(delta: float) -> void:
	for cell in _cells:
		cell.clock += delta
		var frame := int(floor((cell.clock + cell.phase) / FRAME_TIME)) % FRAMES
		if frame != cell.frame:
			cell.frame = frame
			set_cell(cell.coord, cell.source_id, Vector2i(cell.col, frame), cell.alt)


## Is `world_pos` inside a painted cell? The one question ldtk_world.gd's own
## overlap check is built out of — kept here rather than there so the
## coordinate conversion lives with the layer that owns the grid.
func has_water_at(world_pos: Vector2) -> bool:
	return get_cell_source_id(local_to_map(to_local(world_pos))) != -1


## World Y of the water's SURFACE directly above `world_pos` — the top edge of
## the highest unbroken run of painted cells over the one he is standing in.
## INF when that point is not in water at all.
##
## This is what lets Player float at a real resting depth instead of rising
## forever (see swim_buoyancy's own doc for what "forever" used to cost:
## unconditional lift with nothing to settle against, so he climbed until his
## own centre left the top cell, dropped out of SWIM, fell back in, and
## flickered between the two states several times a second). Walked cell by
## cell rather than cached per region, for the same reason _depth_below_surface
## walks: an irregular painted shape has a different surface height over every
## column, and a cave pocket roofed by brick has one that is not the region's
## own top row at all.
func surface_y_at(world_pos: Vector2) -> float:
	var cell := local_to_map(to_local(world_pos))
	if get_cell_source_id(cell) == -1:
		return INF
	while get_cell_source_id(cell + UP) != -1:
		cell += UP
	# map_to_local returns the cell's CENTRE; the surface is its top edge.
	return to_global(map_to_local(cell) - Vector2(0.0, tile_set.tile_size.y * 0.5)).y


## How many painted cells lie directly above `coord`, capped at DEEP_AT — a
## plain walk rather than assuming the first hop is always water, so a future
## change to the rule set can't silently desync this from what LDtk actually
## drew.
func _depth_below_surface(coord: Vector2i, painted: Dictionary) -> int:
	var d := 0
	var probe := coord
	while d < DEEP_AT:
		probe += UP
		if not painted.has(probe):
			break
		d += 1
	return d


## Deterministic float in [0, 1) from two integers — same integer-mix and same
## reasoning as ThoughtHazardLayer._hash() (see that function's doc); kept as
## its own copy here per this project's self-contained-script convention
## rather than a cross-class dependency.
static func _hash01(a: int, b: int) -> float:
	var n := a * 374761393 + b * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / float(0x7fffffff)
