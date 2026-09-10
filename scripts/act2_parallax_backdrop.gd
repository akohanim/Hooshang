class_name Act2ParallaxBackdrop
extends Node2D
## Act 2 Multi-Plane Watercolor Parallax Backdrop (Option C).
##
## Decomposes the watercolor landscape painting into 4 distinct depth planes using Godot 4's
## native Parallax2D nodes:
##   - Layer 0 (Sky Dome & Sun): Moves at deep celestial parallax (0.02, 0.01), never duplicates the sun.
##   - Layer 1 (Watercolor Clouds): Moves at (0.08, 0.03) with subtle atmospheric wind autoscroll (2.5, 0.0).
##   - Layer 2 (Distant Mountains): Moves at (0.20, 0.08), seamless horizontal tiling.
##   - Layer 3 (Near Dunes & Floor): Moves at (0.40, 0.18), anchored to the room floor.
##
## Built with upward zenith sky padding for vertical climbs and downward desert padding for pits.

const TEX_SKY_SUN := preload("res://assets/backdrop/act2_parallax/layer0_sky_sun.png")
const TEX_CLOUDS := preload("res://assets/backdrop/act2_parallax/layer1_clouds.png")
const TEX_MOUNTAINS := preload("res://assets/backdrop/act2_parallax/layer2_mountains.png")
const TEX_DUNES := preload("res://assets/backdrop/act2_parallax/layer3_dunes.png")

@export_group("Parallax Scroll Scales")
@export var sun_scroll_scale := Vector2(0.02, 0.01)
@export var clouds_scroll_scale := Vector2(0.08, 0.03)
@export var clouds_wind_speed := Vector2(2.5, 0.0)
@export var mountains_scroll_scale := Vector2(0.20, 0.08)
@export var dunes_scroll_scale := Vector2(0.40, 0.18)

@export_group("Layout & Offsets")
@export var ground_offset_y := 0.0
@export var margin_x := 128.0

var _world: LdtkWorld
var _layer_sun: Parallax2D
var _layer_clouds: Parallax2D
var _layer_mountains: Parallax2D
var _layer_dunes: Parallax2D


func _ready() -> void:
	z_index = -10
	top_level = true
	_setup_parallax_layers()
	_wait_for_world.call_deferred()


func _setup_parallax_layers() -> void:
	# 1. Layer 0: Sky Dome & Celestial Sun
	_layer_sun = _create_parallax_layer("SunSkyLayer", sun_scroll_scale, Vector2.ZERO, Vector2.ZERO, 1)
	var sun_sprite := _create_sprite(TEX_SKY_SUN)
	_layer_sun.add_child(sun_sprite)
	add_child(_layer_sun)

	# 2. Layer 1: Watercolor Clouds
	var cloud_w := float(TEX_CLOUDS.get_width())
	_layer_clouds = _create_parallax_layer("CloudsLayer", clouds_scroll_scale, Vector2(cloud_w, 0.0), clouds_wind_speed, 5)
	var cloud_sprite := _create_sprite(TEX_CLOUDS)
	_layer_clouds.add_child(cloud_sprite)
	add_child(_layer_clouds)

	# 3. Layer 2: Distant Mountains
	var mount_w := float(TEX_MOUNTAINS.get_width())
	_layer_mountains = _create_parallax_layer("MountainsLayer", mountains_scroll_scale, Vector2(mount_w, 0.0), Vector2.ZERO, 5)
	var mount_sprite := _create_sprite(TEX_MOUNTAINS)
	_layer_mountains.add_child(mount_sprite)
	add_child(_layer_mountains)

	# 4. Layer 3: Near Dunes & Floor Haze
	var dunes_w := float(TEX_DUNES.get_width())
	_layer_dunes = _create_parallax_layer("DunesLayer", dunes_scroll_scale, Vector2(dunes_w, 0.0), Vector2.ZERO, 5)
	var dunes_sprite := _create_sprite(TEX_DUNES)
	_layer_dunes.add_child(dunes_sprite)
	add_child(_layer_dunes)


func _create_parallax_layer(layer_name: String, scale: Vector2, repeat_size: Vector2, autoscroll: Vector2, repeat_times: int) -> Parallax2D:
	var p := Parallax2D.new()
	p.name = layer_name
	p.scroll_scale = scale
	p.repeat_size = repeat_size
	p.autoscroll = autoscroll
	p.repeat_times = repeat_times
	p.follow_viewport = true
	return p


func _create_sprite(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s


func _wait_for_world() -> void:
	var world := _find_world()
	var guard := 0
	while (world == null or world.current_room == null) and guard < 120:
		guard += 1
		await get_tree().process_frame
		world = _find_world()

	if world == null or world.current_room == null:
		return
	_world = world
	# Re-anchor on BOTH edges of a room slide. transition_started fires as the
	# slide BEGINS, carrying the room being entered — so the backdrop is framed
	# for the destination while the camera is still travelling toward it, and is
	# already correct on arrival instead of snapping into place a beat after the
	# player lands (the pop-in the moon had). The layers follow the viewport and
	# tile infinitely, so framing the destination early leaves no gap over the
	# room being left; only the deep sun re-centres, which now glides away as you
	# leave rather than jumping as you arrive. room_changed (slide END) still
	# fires and re-frames the same destination, harmlessly.
	_world.room_changed.connect(_on_room_changed)
	if _world.has_signal("transition_started"):
		_world.transition_started.connect(_on_room_changed)
	_on_room_changed(_world.current_room)


func _on_room_changed(room: Node2D) -> void:
	if room == null or _world == null:
		return
	var rect: Rect2 = _world.room_rect(room)
	var room_center_x := rect.position.x + (rect.size.x * 0.5)
	var ground_y := rect.end.y + ground_offset_y

	# Anchor each layer vertically and center the celestial sun over the room:
	# 1. Dunes base anchors near room floor
	var dunes_y := ground_y - float(TEX_DUNES.get_height()) + 32.0
	_layer_dunes.scroll_offset = Vector2(rect.position.x - margin_x, dunes_y)

	# 2. Mountain horizon sits just above the floor line
	var mount_y := ground_y - float(TEX_MOUNTAINS.get_height()) - 30.0
	_layer_mountains.scroll_offset = Vector2(rect.position.x - margin_x, mount_y)

	# 3. Clouds float across upper midground
	var clouds_y := mount_y - float(TEX_CLOUDS.get_height()) + 80.0
	_layer_clouds.scroll_offset = Vector2(rect.position.x - margin_x, clouds_y)

	# 4. Sun & Sky Dome sits deep in the sky centered on room
	var sun_x := room_center_x - (float(TEX_SKY_SUN.get_width()) * 0.5)
	var sun_y := mount_y - float(TEX_SKY_SUN.get_height()) + 140.0
	_layer_sun.scroll_offset = Vector2(sun_x, sun_y)


func _find_world() -> LdtkWorld:
	var node: Node = self
	while node != null:
		if node is LdtkWorld:
			return node as LdtkWorld
		node = node.get_parent()
	return null
