@tool
class_name GlassSpikes
extends Hazard
## A bed of broken glass: shards set in rubble, lethal on contact. Same rules as
## every other Hazard — it IS a Hazard, so layer, mask and the kill itself are
## inherited and cannot drift apart from the red greybox boxes. All this adds is
## what it looks like and where exactly the lethal part of it is.
##
## Sticks to any of the four surfaces; `facing` is the way the points aim, and
## the bed is always on the surface behind them. Floor and ceiling strips run
## sideways, wall strips run up and down — set the length on that axis and the
## other one takes care of itself.
##
## Drop one in LDtk as `GlassSpikes` (floor), `GlassSpikesCeiling`,
## `GlassSpikesLeftWall` or `GlassSpikesRightWall` and stretch it along the wall
## it is stuck to. Four entities rather than one with a direction field, for the
## same reason the note tiles are five: a field you forget to set is a silent
## wrong answer, and spikes growing out of the ceiling upside down is exactly the
## kind of thing nobody notices until they are playing that room.
##
## The strip is built a cell at a time from assets/hazards/glass_spikes*.png,
## with capped ends and alternating middles so a long run does not read as a
## repeated stamp. Re-generate the art with tools/gen_glass_spikes.py.

## Which way the points aim. UP = a floor strip, DOWN = a ceiling one, RIGHT =
## stuck to the wall on the LEFT, LEFT = stuck to the wall on the right.
enum Facing { UP, DOWN, RIGHT, LEFT }

const SHEETS := {
	Facing.UP: preload("res://assets/hazards/glass_spikes.png"),
	Facing.DOWN: preload("res://assets/hazards/glass_spikes_down.png"),
	Facing.RIGHT: preload("res://assets/hazards/glass_spikes_right.png"),
	Facing.LEFT: preload("res://assets/hazards/glass_spikes_left.png"),
}

const CELL := 16.0
## How much of each cell is glass. The rest is the rubble bed the shards are set
## in, against the surface — and standing in the rubble is not what kills you.
const GLASS_HEIGHT := 12.0

## Which 16px tile of a sheet is which. On a floor strip "first" is the left
## end; on a wall strip it is the top.
enum Tile { SINGLE, FIRST, MIDDLE_A, MIDDLE_B, LAST }

@export var facing: Facing = Facing.UP:
	set(value):
		facing = value
		_update_extents()


## A strip BOLTED to a WALL does not come down when the room does — a ceiling
## strip does, same as a floor one.
##
## Two reasons a wall strip stays put, and the second is the one that mattered
## in play:
##
##   1. It looks wrong. RoomCollapse drops a prop straight down and leaves its
##      art alone, so a wall strip that falls ends up lying on the floor with its
##      points aimed sideways — spikes growing out of nothing.
##   2. It breaks rooms. Room 16 is a vertical gauntlet built out of two 112px
##      wall strips facing each other; dropping them piled the whole hazard onto
##      the floor across the only route through, and the room became impossible.
##
## A ceiling strip does not have either problem: it runs the same axis a floor
## strip does, so `collapse_landed()` below only has to flip its facing, not
## rebuild its layout, and there is no gauntlet built out of ceiling strips
## facing anything. Its mount lets go and it crashes to the floor like anything
## else hanging in the room.
##
## See RoomCollapse._falls — an anchored prop is not in the collapse at all, so
## it also goes on counting as ground for anything resting on it.
func collapse_anchored() -> bool:
	return facing == Facing.LEFT or facing == Facing.RIGHT


## Called by RoomCollapse the instant a falling strip reaches the floor. A
## ceiling strip's points aim down; landed on the floor that way they'd be
## drawn burrowing into it rather than threatening whatever stands on them, so
## it becomes a floor strip on impact — the mount is gone either way, and what
## is left is a spike strip lying on the ground. Re-assigning `facing` reruns
## `_update_extents()` through its own setter, which re-skins it and slides the
## kill box the couple of px a floor strip's offset differs by.
func collapse_landed() -> void:
	if facing == Facing.DOWN:
		facing = Facing.UP

var _row: Node2D


## Wall strips run up and down, floor and ceiling strips run sideways.
func _vertical() -> bool:
	return facing == Facing.RIGHT or facing == Facing.LEFT


func _build_visual() -> void:
	_row = Node2D.new()
	_row.name = "Shards"
	_visual = _row
	add_child(_row)


## Lay out the strip and put the kill box around the GLASS only.
##
## Inset from the glass rather than from the whole cell, so a player running
## along a wall lined with these is not killed by the rubble they are set in —
## the visible thing that hurts is the part that hurts.
func _update_extents() -> void:
	if _shape == null:
		return
	var length: float = size.y if _vertical() else size.x
	var cells := maxi(int(round(length / CELL)), 1)
	_rebuild(cells)
	var along := cells * CELL - KILL_MARGIN * 2.0
	var across := GLASS_HEIGHT - KILL_MARGIN * 2.0
	_shape.shape.size = (Vector2(across, along) if _vertical()
		else Vector2(along, across)).max(Vector2.ONE)
	# The glass sits at whichever end of the cell it points towards, so the kill
	# box shifts off centre by half the bed.
	var offset := (CELL - GLASS_HEIGHT) * 0.5
	match facing:
		Facing.UP: _shape.position = Vector2(0.0, -offset)
		Facing.DOWN: _shape.position = Vector2(0.0, offset)
		Facing.RIGHT: _shape.position = Vector2(offset, 0.0)
		Facing.LEFT: _shape.position = Vector2(-offset, 0.0)


func _rebuild(cells: int) -> void:
	if _row == null:
		return
	for old in _row.get_children():
		old.free()   # free, not queue_free: this reruns on every size nudge in
					 # the editor, and queued nodes would still be here for the
					 # next pass and stack up.
	for i in cells:
		var shard := Sprite2D.new()
		shard.texture = _tile(_variant(i, cells))
		shard.centered = false
		var step := i * CELL - cells * CELL * 0.5
		shard.position = Vector2(-CELL * 0.5, step) if _vertical() \
			else Vector2(step, -CELL * 0.5)
		_row.add_child(shard)


## Capped at both ends, alternating in the middle.
func _variant(i: int, cells: int) -> Tile:
	if cells == 1:
		return Tile.SINGLE
	if i == 0:
		return Tile.FIRST
	if i == cells - 1:
		return Tile.LAST
	return Tile.MIDDLE_A if i % 2 else Tile.MIDDLE_B


## Wall sheets stack their tiles down the image; floor and ceiling sheets lay
## them out across it. Same five tiles, same order, one axis apart.
func _tile(which: Tile) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = SHEETS[facing]
	var step := int(which) * CELL
	tex.region = Rect2(0.0, step, CELL, CELL) if _vertical() \
		else Rect2(step, 0.0, CELL, CELL)
	return tex
