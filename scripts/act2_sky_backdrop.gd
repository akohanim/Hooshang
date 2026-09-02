class_name Act2SkyBackdrop
extends Node2D
## Act 2's sky: the user-supplied watercolor landscape, cut by
## tools/gen_act2_sky_backdrop.py into two pieces so a room can be wider than
## the source painting WITHOUT repeating the sun — see that script's own
## header for the full reasoning. CENTER (the sun) is placed exactly once,
## horizontally centred on the CURRENT room; EXTEND (a sun-free slice of the
## same painting) tiles outward from both of CENTER's edges, alternating a
## horizontal mirror each copy so it does not read as one stamp repeating
## (same rule ConveyorBelt/GlassSpikes/SlideZone's floor already follow for
## their own repeating strips), until that room (plus `margin`) is covered.
##
## RE-ANCHORED PER ROOM, not one fixed image for the whole world. The first
## version of this file anchored to the UNION of every room's bounds instead —
## which reads fine while Act 2 is one room, but breaks the moment a second
## room sits far away vertically (exactly what this project's own dev-only
## showcase room did: it pulled the shared ground-line 600px down, leaving the
## real starting room's own band showing nothing at all). Act 1's own
## precedent is a full 2D room grid, not one row, so a single static backdrop
## covering literally the whole world was never going to read as one sky
## everywhere anyway — re-anchoring per room, the way this project already
## re-derives per-room lighting/backdrops, is the version that actually holds
## up as more rooms get added.
##
## BUILT LAZILY, then kept in sync with LdtkWorld's own `room_changed` signal.
## The first room is not knowable until LdtkWorld's own _ready() has
## instantiated the LDtk world — which runs AFTER this node's _ready(), since
## Godot runs a child's _ready() before its parent's and this node sits nested
## under Act2World. So this polls once for `rooms`/`current_room` to exist,
## the same way tests/room_shot.gd already does, rather than assuming an
## ordering Godot does not guarantee.
##
## Lives inside the game viewport (a child of Act2World, not a separate
## CanvasLayer) so it sits behind CanvasModulate's warm daylight tint like
## everything else in the room — the same trap parallax_backdrop.gd's own
## header documents for a backdrop that tried to escape it.

const CENTER := preload("res://assets/backdrop/act2_sky/center.png")
const EXTEND := preload("res://assets/backdrop/act2_sky/extend.png")

## How far the art's own ground line (where the mountains meet the sky) sits
## below CENTER's top edge, in the art's own pixels — measured off center.png,
## not eyeballed. NOT simply "first non-blue pixel scanning down the centre
## column": that column runs straight through the sun, and a first pass that
## used it landed on the SUN's own edge (row 265) instead of the mountains,
## which sit much lower — the sun and the pale-cream sky right around it read
## as "non-sky" under a naive blue-vs-not check just as readily as the actual
## ridge does. Re-measured by scanning several columns AWAY from the sun for
## the first distinctly warm/orange (mountain) pixel, which agreed at ~485-532
## depending on x (the ridge is irregular); 500 is representative.
const GROUND_LINE_Y := 500.0

## How far past the current room's own edge the sky should still visibly
## cover, in px, so it never visibly runs out right at the room boundary.
@export var margin := 96.0
## Nudges where the art's ground line lands relative to the current room's
## own bottom edge, in px (positive pushes the art down, i.e. buries more of
## the mountains below the visible floor). 0 lines the ground line up with
## that room's own floor — a reasonable first pass; retune per real level
## layout once Act 2 has real rooms with their own floor heights.
@export var ground_offset_y := 0.0

var _world: LdtkWorld


func _ready() -> void:
	# Behind every room's own tiles and RoomBackdrop panel (z_index -1) and
	# behind DarkThought/CeilingPanel's own z_index 1 — see LIGHTING.md's
	# draw-order note. Comfortably below all of them.
	z_index = -10
	top_level = true  # world-space, not room-local — see _rebuild()'s own note
	_wait_for_world.call_deferred()


func _wait_for_world() -> void:
	var world := _find_world()
	var guard := 0
	while (world == null or world.current_room == null) and guard < 120:
		guard += 1
		await get_tree().process_frame
		world = _find_world()
	if world == null or world.current_room == null:
		return  # a test/editor context with no real room — nothing to draw
	_world = world
	_world.room_changed.connect(_rebuild)
	_rebuild(_world.current_room)


func _rebuild(room: Node2D) -> void:
	for child in get_children():
		child.queue_free()
	if room == null:
		return
	var rect: Rect2 = _world.room_rect(room).grow_individual(margin, 0.0, margin, 0.0)

	# top_level = true makes `position` a WORLD position regardless of where
	# this node sits in the scene tree — so the tiles below are laid out
	# directly in world space, the same coordinate room_rect() already
	# returns. TOP-LEFT anchored (see _sprite — centered=false): GROUND_LINE_Y
	# is measured DOWN from a tile's top edge, so a tile placed at
	# y = ground_y - GROUND_LINE_Y puts its ground line exactly at ground_y.
	var center_x := rect.position.x + rect.size.x * 0.5
	var ground_y := rect.end.y + ground_offset_y
	var top_y := ground_y - GROUND_LINE_Y

	var center_w: float = CENTER.get_width()
	var center := _sprite(CENTER, false)
	center.position = Vector2(center_x - center_w * 0.5, top_y)
	add_child(center)

	var extend_w: float = EXTEND.get_width()
	var left_edge := center_x - center_w * 0.5
	var right_edge := center_x + center_w * 0.5
	var mirror := false
	while left_edge > rect.position.x:
		left_edge -= extend_w
		var left_tile := _sprite(EXTEND, mirror)
		left_tile.position = Vector2(left_edge, top_y)
		add_child(left_tile)
		mirror = not mirror
	mirror = false
	while right_edge < rect.end.x:
		var right_tile := _sprite(EXTEND, mirror)
		right_tile.position = Vector2(right_edge, top_y)
		right_edge += extend_w
		add_child(right_tile)
		mirror = not mirror


## One backdrop tile, TOP-LEFT anchored (centered=false) so the layout math in
## _rebuild() can position it by simple top-left coordinates, the same
## convention Platform/ConveyorBeltVisual/every other precisely-tiled prop in
## this project already uses — Sprite2D defaults to centred, which is what
## the very first version of this file got wrong (positioned everything
## roughly a half-image-size too high). Smoothly filtered: the one deliberate
## exception to this project's nearest-neighbour pixel-art rule, same
## exemption SunShaft/MoonWindow/the archway backdrop experiment already
## carry — this is watercolor concept art shown at (near) its own resolution,
## never squeezed onto the 8px tile grid, and a nearest-neighbour scale would
## turn its soft bleed to mud.
func _sprite(tex: Texture2D, mirror: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.flip_h = mirror
	return s


func _find_world() -> LdtkWorld:
	var node: Node = self
	while node != null:
		if node is LdtkWorld:
			return node as LdtkWorld
		node = node.get_parent()
	return null
