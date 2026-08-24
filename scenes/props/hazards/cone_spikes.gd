@tool
class_name ConeSpikes
extends Hazard
## A row of small conical spikes, one grid cell tall, lethal on contact. Same
## rules as every other Hazard — it IS a Hazard, so layer, mask and the kill
## itself are inherited and cannot drift apart from the red greybox boxes. All
## this adds is what it looks like and where exactly the lethal part of it is.
##
## THE SMALL ONE. GlassSpikes is the same idea at 16px, two cells deep; this is
## 8, a single cell, for a floor you want threatened without giving up half the
## room's height to the hazard. Everything below is that halving — see CELL and
## CONE_HEIGHT, which are the two numbers you cannot simply copy across.
##
## Sticks to any of the four surfaces; `facing` is the way the points aim, and
## the base is always on the surface behind them. Floor and ceiling strips run
## sideways, wall strips run up and down — set the length on that axis and the
## other one takes care of itself.
##
## Drop one in LDtk as `ConeSpikes` (floor), `ConeSpikesCeiling`,
## `ConeSpikesLeftWall` or `ConeSpikesRightWall` and stretch it along the wall it
## is stuck to. Four entities rather than one with a direction field, for the
## same reason the note tiles are five: a field you forget to set is a silent
## wrong answer, and spikes growing out of the ceiling upside down is exactly the
## kind of thing nobody notices until they are playing that room.
##
## The strip is built a cell at a time from assets/hazards/cone_spikes*.png, with
## capped ends and alternating middles so a long run does not read as a repeated
## stamp. Re-generate the art with tools/gen_cone_spikes.py.

## Which way the points aim. UP = a floor strip, DOWN = a ceiling one, RIGHT =
## stuck to the wall on the LEFT, LEFT = stuck to the wall on the right.
enum Facing { UP, DOWN, RIGHT, LEFT }

const SHEETS := {
	Facing.UP: preload("res://assets/hazards/cone_spikes.png"),
	Facing.DOWN: preload("res://assets/hazards/cone_spikes_down.png"),
	Facing.RIGHT: preload("res://assets/hazards/cone_spikes_right.png"),
	Facing.LEFT: preload("res://assets/hazards/cone_spikes_left.png"),
}

## ONE CELL. The whole point of this hazard against GlassSpikes' two.
const CELL := 8.0
## How much of each cell is cone. The rest is the base they are set in, against
## the surface — and standing in the base is not what kills you. Matches
## BASE_TOP in tools/gen_cone_spikes.py; the art and this have to agree, or the
## lethal band sits somewhere the player cannot see a reason for.
const CONE_HEIGHT := 5.0
## How much of the POINTED end is not lethal, in px.
##
## This is here because Hazard.KILL_MARGIN cannot do the job at 8px. It insets
## 2px from every side, which on GlassSpikes' 12px of glass leaves 8 — a modest
## leniency. Against 5px of cone it would leave ONE pixel, a hazard you could
## stand in the middle of, so applying it across the cone is not a safer version
## of this hazard but a broken one.
##
## So the across axis gets its own number, and it is shaved off the TIP only.
## That is where leniency belongs: the top pixel of a cone is one pixel wide and
## brushing it should not kill, while the bottom of the cone is full width and
## unambiguously a spike. The base end is not inset at all — the kill box stops
## exactly where the cones do, which is what keeps standing in the base safe.
const TIP_LENIENCY := 1.0

## Which 8px tile of a sheet is which. On a floor strip "first" is the left end;
## on a wall strip it is the top.
enum Tile { SINGLE, FIRST, MIDDLE_A, MIDDLE_B, LAST }

@export var facing: Facing = Facing.UP:
	set(value):
		facing = value
		_update_extents()


## A strip BOLTED to a WALL does not come down when the room does — a ceiling
## strip does, same as a floor one. Same reasoning as GlassSpikes, and it
## matters for the same two reasons: a fallen wall strip lies on the floor with
## its points aimed sideways, and a room built out of facing wall strips becomes
## impossible when they all pile onto the only route through.
func collapse_anchored() -> bool:
	return facing == Facing.LEFT or facing == Facing.RIGHT


## Called by RoomCollapse the instant a falling strip reaches the floor. A
## ceiling strip's points aim down; landed that way they would be drawn
## burrowing into the floor rather than threatening what stands on them.
func collapse_landed() -> void:
	if facing == Facing.DOWN:
		facing = Facing.UP

var _row: Node2D


## Wall strips run up and down, floor and ceiling strips run sideways.
func _vertical() -> bool:
	return facing == Facing.RIGHT or facing == Facing.LEFT


func _build_visual() -> void:
	_row = Node2D.new()
	_row.name = "Cones"
	_visual = _row
	add_child(_row)


## Lay out the strip and put the kill box around the CONES only.
func _update_extents() -> void:
	if _shape == null:
		return
	var length: float = size.y if _vertical() else size.x
	var cells := maxi(int(round(length / CELL)), 1)
	_rebuild(cells)
	var along := maxf(cells * CELL - KILL_MARGIN * 2.0, 1.0)
	var across := maxf(CONE_HEIGHT - TIP_LENIENCY, 1.0)
	_shape.shape.size = (Vector2(across, along) if _vertical()
		else Vector2(along, across)).max(Vector2.ONE)
	# The cones sit at whichever end of the cell they point towards, so the kill
	# box shifts off centre. Measured from the cell's leading edge: skip the
	# leniency at the tip, then half the lethal band.
	var offset := CELL * 0.5 - TIP_LENIENCY - across * 0.5
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
		var cone := Sprite2D.new()
		cone.texture = _tile(_variant(i, cells))
		cone.centered = false
		var step := i * CELL - cells * CELL * 0.5
		cone.position = Vector2(-CELL * 0.5, step) if _vertical() \
			else Vector2(step, -CELL * 0.5)
		_row.add_child(cone)


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
