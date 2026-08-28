class_name ThoughtHazardLayer
extends TileMapLayer
## Runtime driver for the paintable ThoughtHazards tiles (see STYLE_GUIDE.md
## §9). Attached at import time (ldtk_level_post_import.gd) to every
## ThoughtHazards TileMapLayer, the same way LdtkDoor and LdtkRumiTrigger are
## swapped onto their nodes — a script attached at import time survives being
## packed into the saved .scn; a signal CONNECTED at import time does not,
## which is why this is a script and not logic living in the post-import hook.
##
## WHY NOT TileSet's OWN ANIMATION. Godot's tile animation
## (set_tile_animation_frame_duration etc.) is ONE shared clock per ATLAS
## TILE — every cell painted with that tile plays the identical frame at the
## identical instant, world-wide. A room with a dozen painted cells bred and
## blinked as one synchronised mass, which reads as a grid pulsing in lockstep
## rather than as many small living things. This script instead treats the
## sheet's six rows as six ordinary, independently-addressable tiles (the
## importer already creates all of them for every non-empty cell — see the
## PATCHED note in addons/ldtk-importer/src/tileset.gd) and swaps each cell's
## atlas coords by hand, on its OWN per-cell clock and its OWN per-cell speed.
##
## THE PHASE AND SPEED ARE HASHED FROM THE CELL, not random. Two reasons: a
## room has to read the same way every time you enter it — the same reason
## DarkThought.reset_all() exists — and the project avoids RNG in generated
## behaviour for exactly that reproducibility (see gen_dark_thought.py,
## gen_thought_tiles.py). A hash of the cell's own coordinates gives every
## painted cell a stable, UNCORRELATED phase and playback rate with no seed to
## manage and no two runs that could ever disagree.

## Rows on the sheet, and how long one occupies the screen. Matches the
## generator (tools/gen_thought_tiles.py: FRAMES = 6) and the pace the old
## baked animation ran at.
const FRAMES := 6
const FRAME_TIME := 0.18

## Per-cell speed spread. 0.85-1.15x is wide enough that cells visibly drift in
## and out of step with each other over a few cycles — which is what actually
## reads as "random" rather than "offset" — and narrow enough that a fast cell
## never laps a slow one within a single breath, which would look like a skip.
const SPEED_MIN := 0.85
const SPEED_SPREAD := 0.30


class _Cell:
	var coord: Vector2i
	var source_id: int
	var col: int          ## tile type: 0 fill, 1 top, 2 left, 3 corner
	var clock := 0.0        ## this cell's OWN elapsed time
	var speed := 1.0         ## this cell's OWN playback rate
	var phase := 0.0          ## this cell's OWN start offset, in seconds
	var frame := -1            ## last atlas row actually drawn; -1 forces the first set_cell


var _cells: Array[_Cell] = []


func _ready() -> void:
	for coord in get_used_cells():
		var cell := _Cell.new()
		cell.coord = coord
		cell.source_id = get_cell_source_id(coord)
		cell.col = get_cell_atlas_coords(coord).x
		# Two INDEPENDENT hashes, not one reused for both speed and phase — reusing
		# one would correlate them (a cell hashed fast would also always start
		# late), and correlated numbers are exactly the kind of structure that
		# reads as a pattern instead of as random.
		cell.speed = SPEED_MIN + SPEED_SPREAD * _hash(coord)
		cell.phase = _hash(coord + Vector2i(1000, 1000)) * FRAMES * FRAME_TIME
		_cells.append(cell)
	# No process cost on a room with nothing painted.
	set_process(not _cells.is_empty())


func _process(delta: float) -> void:
	for cell in _cells:
		cell.clock += delta * cell.speed
		var frame := int(floor((cell.clock + cell.phase) / FRAME_TIME)) % FRAMES
		if frame != cell.frame:
			cell.frame = frame
			set_cell(cell.coord, cell.source_id, Vector2i(cell.col, frame))


## Deterministic float in [0, 1) from a cell coordinate. Not Godot's built-in
## `hash()` — this is the same integer-mix gen_thought_tiles.py's own `_hash()`
## uses for its body dither, kept in step so a reader who has seen one
## recognises the other, and so both stay independent of anything Godot's own
## hash implementation might change between engine versions.
static func _hash(coord: Vector2i) -> float:
	var n := coord.x * 374761393 + coord.y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / float(0x7fffffff)
