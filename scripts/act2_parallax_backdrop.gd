class_name Act2ParallaxBackdrop
extends Node2D
## One extended watercolor painting across the whole act. Its finite camera
## travel reveals new terrain, with no tiling, mirroring or room-local reset.
## The sun is a separate singleton; the landscape contains no painted suns.

## Extra painting height provides room for a gentle vertical parallax drift.
@export_range(1.0, 2.0) var panorama_height := 1.3
## Sun canvas size in design pixels (the transparent margin is included).
@export var sun_size := 52.0
## Fixed normalized position in the painting, independent of player or room.
@export var sun_anchor := Vector2(0.47, 0.38)

@onready var landscape: Sprite2D = $Landscape
@onready var sun: Sprite2D = $Sun
@onready var landmarks: Node2D = $Landmarks
## 0 = daytime, 1 = below the horizon; driven only by the story clock.
var sun_descent := 0.0
var _world: LdtkWorld
var _bounds := Rect2()


func _ready() -> void:
	add_to_group("act2_sky")
	top_level = true
	# Camera smoothing can update the canvas after ordinary _process calls.
	# Reconcile at render time so a fixed backdrop never trails it by a frame.
	RenderingServer.frame_pre_draw.connect(_sync_to_camera)
	_wait_for_world.call_deferred()


func _wait_for_world() -> void:
	var node := get_parent()
	while node != null and not node is LdtkWorld:
		node = node.get_parent()
	_world = node as LdtkWorld
	if _world == null:
		return
	for _frame in 120:
		if not _world.rooms.is_empty():
			break
		await get_tree().process_frame
	if _world.rooms.is_empty():
		return
	_bounds = _world.room_rect(_world.rooms[0])
	for room in _world.rooms:
		_bounds = _bounds.merge(_world.room_rect(room))
		# LDtk keeps these paintings as authoring references. They duplicate the
		# old sky and would cover this shared panorama in the first two rooms.
		var old_image := room.get_node_or_null("BG Image") as CanvasItem
		if old_image != null:
			old_image.hide()
	landmarks.configure(_world)
	# No room-change callback: the camera itself moves smoothly through the
	# room slide, backwards travel, and the third room's tall climb.
	_process(0.0)


func _sync_to_camera() -> void:
	_process(0.0)


func _process(_delta: float) -> void:
	if _bounds.size == Vector2.ZERO:
		return
	var canvas := get_viewport().get_canvas_transform()
	var inverse := canvas.affine_inverse()
	var viewport_size := get_viewport_rect().size
	var view := Rect2(inverse * Vector2.ZERO,
		(inverse * viewport_size) - (inverse * Vector2.ZERO))
	# Remain a world CanvasItem so Act 2's daylight/sunset tint still applies.
	# Cancelling the camera transform lets framing use design-screen pixels.
	global_transform = inverse
	_frame_view(view, viewport_size)


func _frame_view(view: Rect2, viewport_size: Vector2) -> void:
	var travel := (_bounds.size - view.size).max(Vector2.ONE)
	var progress := ((view.position - _bounds.position) / travel).clamp(Vector2.ZERO, Vector2.ONE)
	var art_scale := maxf(viewport_size.y * panorama_height / landscape.texture.get_height(),
		viewport_size.x / landscape.texture.get_width())
	landscape.scale = Vector2.ONE * art_scale
	var excess := landscape.texture.get_size() * art_scale - viewport_size
	landscape.position = -excess * progress
	landmarks.frame_view(view, viewport_size)
	# The disc belongs to the painting: it travels exactly with the scenery,
	# including vertical climbs. Never clamp it to the screen or re-centre it
	# on room entry; leaving the camera view is natural.
	sun.scale = Vector2.ONE * sun_size / sun.texture.get_width()
	var anchor := Vector2(sun_anchor.x, lerpf(sun_anchor.y, 0.86, sun_descent))
	var painting_size := landscape.texture.get_size() * art_scale
	sun.position = landscape.position + painting_size * anchor
	var horizon_y := landscape.position.y + painting_size.y * 0.70
	var sun_top := sun.position.y - sun_size * 0.5
	(sun.material as ShaderMaterial).set_shader_parameter("horizon_uv", (horizon_y - sun_top) / sun_size)
	sun.self_modulate = Color.WHITE.lerp(Color(1.0, 0.48, 0.20), sun_descent)
	sun.visible = sun_descent < 1.0


func set_sun_descent(value: float) -> void:
	sun_descent = clampf(value, 0.0, 1.0)
