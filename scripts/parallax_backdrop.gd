extends Sprite2D
## A level's LDtk background image (see CLAUDE.md's "background image" note),
## lagging the camera so it reads as sitting behind the Collisions layer
## instead of pinned to it.
##
## Deliberately NOT a Godot ParallaxBackground/ParallaxLayer: those are
## CanvasLayers, and this room's CanvasModulate only multiplies its OWN
## canvas — moving the sprite into a separate canvas layer would escape that
## dimming entirely and the photo would render at full brightness against a
## darkened room (the same trap SunShaft/WallPattern/CeilingPanel document
## for lights, here for a whole background). Staying a plain Sprite2D and
## just re-positioning it every frame keeps it in the room's own canvas, so
## CanvasModulate keeps applying exactly as it did before this script existed.
##
## `motion_scale` of 1.0 tracks the camera 1:1 (no parallax, same as a plain
## static Sprite2D); 0.0 stays fixed on screen regardless of camera movement.
## The art must be pre-sized wider than the room by the caller (see
## ldtk_level_post_import.gd) — at motion_scale m the sprite needs to be at
## least `viewport_w + m * (room_w - viewport_w)` wide, or the room's far
## edge outruns it and shows empty space past the image.
@export var motion_scale := Vector2(0.5, 0.5)

var _neutral_global: Vector2
## The room's own centre — NOT read from the camera's limit_left/right/etc,
## even though on paper those describe the same rect (LdtkWorld sets them to
## room_rect on entry). Camera limits are transient: whatever ELSE last
## called set_camera_limits() (Act1Beats' startup wiring walks every room's
## exits, a cross-room slide unions two rects) can leave them pointed at
## another room, or a rect wider than this one, on the very first frame this
## script runs — and unlike a one-time mis-sample of a moving value, arming
## against that would be wrong for the sprite's entire lifetime. The level
## node's own `size`/`world_position` (this sprite's parent) are the level's
## OWN geometry, exported by the LDtk importer and never touched by camera
## code at all, so they're right immediately and can't be raced.
var _neutral_cam: Vector2
var _level: Node2D
var _world: LdtkWorld


func _ready() -> void:
	# Same z-band as the room's flat RoomBackdrop colour (ldtk_world.gd's
	# _add_backdrop, z -1) and the level's own painted "Background" tile
	# layer (ldtk_level_post_import.gd's Z_BANDS) — this photo is a richer
	# stand-in for that same flat wall colour, not a layer further back
	# than it. Sibling order at equal z is what keeps the three in the
	# right relative order: RoomBackdrop is moved to child index 0 by
	# _add_backdrop, this sprite is added by the LDtk importer before the
	# level's own tile layers, so the draw order comes out RoomBackdrop (a
	# fallback, now always covered) -> this photo -> the level's own
	# Background tiles. Critically, -1 is still BELOW the default z_index 0
	# that MoonWindow/MoonGlow/WallPattern/SunShaft use (they live under
	# Act1World's own Backdrop/Lights nodes, siblings of the instantiated
	# LDtk world) — without an explicit z here this sprite would tie with
	# them at 0, and since ldtk_world.gd's _ready() adds the LDtk world
	# (and so this sprite) AFTER Backdrop/Lights, plain tree order would
	# draw it ON TOP and bury them, which is what motivated this in the
	# first place. -2 (an earlier attempt) overshot: that put it BEHIND
	# RoomBackdrop too, so the flat colour covered the photo completely.
	z_index = -1
	_neutral_global = global_position
	_level = get_parent()
	var level := _level as LDTKLevel
	_neutral_cam = level.global_position + Vector2(level.size) * 0.5
	var p := get_parent()
	while p != null:
		if p is LdtkWorld:
			_world = p
			break
		p = p.get_parent()


func _process(_delta: float) -> void:
	# Every room's level (and its background) coexists in the tree at once —
	# there's no per-room loading/unloading — and there is only ever ONE
	# active Camera2D, the player's. Without this gate, EVERY room's
	# background reacts to that one camera regardless of which room it
	# belongs to: a neighbouring room's background (Level_2's, sized and
	# positioned for its OWN much wider room) would swing based on the
	# camera's position while standing in THIS room and visibly bleed into
	# view — reported as "the background overlaps" once Level_2 was placed
	# directly next to Level_1. Sitting still at the neutral (undisplaced)
	# position is always safe: that position is exactly where this sprite
	# was authored to sit over its own room, so it never spills into a
	# neighbour even though it stops tracking the camera.
	if _world != null and _world.current_room != _level:
		global_position = _neutral_global
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	# get_screen_center_position(), not global_position: the latter is the
	# camera's raw (unclamped) transform, which keeps changing as the player
	# walks past a room edge even though the CLAMPED view has stopped panning
	# — using it would slide the backdrop against a foreground that has
	# visually already stopped.
	var delta := cam.get_screen_center_position() - _neutral_cam
	global_position = _neutral_global + delta * (Vector2.ONE - motion_scale)
