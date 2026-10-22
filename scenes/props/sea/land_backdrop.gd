class_name LandBackdrop
extends Node2D
## The way home's painted rooms (Act3_Level_25..31) in depth: the planes
## tools/gen_act3_land_backdrops.py paints into assets/act3/land/<room>/, hung
## at their depths and brought to life. Clouds drift, trees and grass bend in one
## wind that crosses the room, the sea glints, light shafts breathe, a waterfall
## falls, gulls cross now and then, and seeds, petals, leaves and motes blow
## through, some behind the land and some in front of it. Built by
## SeaRoom._build_backdrop for any room that has a `layers.json`.
##
## The planes HOLD STILL. They are laid out once, fixed to the room, and only
## the things that live in them move (clouds, wind, water, birds). They used to
## slide: a plane at depth `p` followed the camera by (1 - p) of its travel,
## and, since these rooms are one screen wide and the camera never pans
## sideways, by a few pixels as HE walked. On screen that read as the mountains
## and the sea moving, not as depth: nothing in front of them was scrolling, so
## there was nothing for them to be slower than. `p` is kept in the manifest as
## the painter's depth order. The planes are still painted with the margins that
## slide needed; the clip below keeps those off the neighbouring rooms.

const DIR := "res://assets/act3/land/%s/"
const SWAY := preload("res://assets/shaders/act3_land_sway.gdshader")
const GRASS := preload("res://assets/shaders/act3_land_grass.gdshader")
const GLINT := preload("res://assets/shaders/act3_land_glint.gdshader")
const FX_MODES := {"twinkle": 0, "pulse": 1, "fall": 2}
var room_size := Vector2(320, 192)
## Room y of the ground in each column (the painter's `ground`), or empty.
var ground := PackedInt32Array()
## Everything is drawn inside this room-sized clip: the planes are painted wider
## than the room, and the margins would otherwise lie over the NEIGHBOURING
## rooms (a strip of the wood showing at the meadow's edge).
var _clip: Control
var _planes: Array[Dictionary] = []
var _ground_tex: Texture2D
var _ground_origin := Vector2.ZERO
var _clouds: Array[Dictionary] = []
var _birds: Dictionary = {}
var _flock: Array[Dictionary] = []
var _next_flock := 0.0
var _bird_frames: SpriteFrames
var _t := 0.0
var _rng := RandomNumberGenerator.new()


static func manifest_path(room_name: String) -> String:
	return (DIR % room_name) + "layers.json"


static func exists_for(room_name: String) -> bool:
	return ResourceLoader.exists(manifest_path(room_name))


## Hang the room's planes. False (and nothing built) if its manifest is unreadable.
func build(room_name: String) -> bool:
	var json := load(manifest_path(room_name)) as JSON
	if json == null or not json.data is Dictionary:
		push_error("LandBackdrop: %s is missing or unreadable" % manifest_path(room_name))
		return false
	var data: Dictionary = json.data
	var dir := DIR % room_name
	_rng.seed = hash(room_name)
	room_size = Vector2(data["room"][0], data["room"][1])
	_clip = Control.new()
	_clip.name = "Clip"
	_clip.clip_contents = true
	_clip.size = room_size
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	for y in data.get("ground", []):
		ground.append(int(y))
	if ResourceLoader.exists(dir + "ground.png"):
		_ground_tex = load(dir + "ground.png")
		var gm: Array = data.get("ground_margin", [3, 3])
		_ground_origin = global_position - Vector2(gm[0], gm[1])
	for layer: Dictionary in data["layers"]:
		_add_plane(dir, layer)
	for cloud: Dictionary in data.get("clouds", []):
		_add_cloud(dir, cloud)
	for tree: Dictionary in data.get("trees", []):
		_add_tree(dir, tree)
	if data.has("birds") and ResourceLoader.exists(dir + "bird.png"):
		_birds = data["birds"]
		_bird_frames = _bird_sheet(load(dir + "bird.png"))
		_next_flock = _rng.randf_range(1.0, float(_birds["every"][0]))
	for spec: Dictionary in data.get("particles", []):
		_add_motes(spec)
	return true


# ----------------------------------------------------------------- planes ----

func _sprite(texture: Texture2D, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = false
	s.z_as_relative = false
	s.z_index = z
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_clip.add_child(s)
	return s


func _add_plane(dir: String, layer: Dictionary) -> void:
	var s := _sprite(load(dir + str(layer["texture"])), int(layer["z"]))
	s.name = str(layer["name"]).to_pascal_case()
	var margin := Vector2(layer["margin"][0], layer["margin"][1])
	var shader := str(layer.get("shader", ""))
	if shader == "grass" and _ground_tex != null:
		var m := ShaderMaterial.new()
		m.shader = GRASS
		m.set_shader_parameter("ground", _ground_tex)
		m.set_shader_parameter("sway", float(layer.get("sway", 1.0)))
		s.material = m
	elif shader == "hang":
		var m := ShaderMaterial.new()
		m.shader = SWAY
		m.set_shader_parameter("from_top", true)
		m.set_shader_parameter("whole", false)
		m.set_shader_parameter("reach", 26.0)
		m.set_shader_parameter("pad", 0.0)
		m.set_shader_parameter("sway", float(layer.get("sway", 1.0)))
		s.material = m
	elif FX_MODES.has(shader):
		var m := ShaderMaterial.new()
		m.shader = GLINT
		m.set_shader_parameter("mode", FX_MODES[shader])
		s.material = m
	s.position = -margin
	_planes.append({node = s, base = -margin, p = float(layer["p"]), layer = true})


func _add_cloud(dir: String, cloud: Dictionary) -> void:
	var s := _sprite(load(dir + str(cloud["texture"])), int(cloud["z"]))
	s.name = "Cloud"
	var size := Vector2(cloud["size"][0], cloud["size"][1])
	_clouds.append({node = s, x = float(cloud["x"]) - size.x / 2.0, y = float(cloud["y"]) - size.y / 2.0,
		w = size.x, p = float(cloud["p"]), speed = float(cloud["speed"])})


func _add_tree(dir: String, tree: Dictionary) -> void:
	var s := _sprite(load(dir + str(tree["texture"])), int(tree["z"]))
	s.name = "Tree"
	var size := Vector2(tree["size"][0], tree["size"][1])
	var m := ShaderMaterial.new()
	m.shader = SWAY
	m.set_shader_parameter("sway", float(tree.get("sway", 1.0)))
	m.set_shader_parameter("phase", float(tree.get("phase", 0.0)))
	m.set_shader_parameter("speed", 0.85 + 0.1 * fmod(float(tree.get("phase", 0.0)), 3.0))
	s.material = m
	var base := Vector2(float(tree["x"]) - float(tree["anchor"]), float(tree["y"]) - size.y + 1.0)
	s.position = base
	_planes.append({node = s, base = base, p = float(tree["p"]), layer = false})


## Give the room's terrain material (act3_depth_tint) body: darker with depth
## below the room's ground line.
func shade_earth(terrain: ShaderMaterial) -> void:
	if _ground_tex == null or terrain == null:
		return
	terrain.set_shader_parameter("ground", _ground_tex)
	terrain.set_shader_parameter("ground_origin", _ground_origin)
	terrain.set_shader_parameter("earth_depth", 0.45)


# --------------------------------------------------------------- per frame ----

func _process(delta: float) -> void:
	_t += delta
	_drift_clouds()
	if not _birds.is_empty():
		_fly_birds(delta)


## Clouds drift with the wind, off one side and back in at the other.
func _drift_clouds() -> void:
	for cloud in _clouds:
		var w: float = cloud.w
		var left := -w - 16.0
		var x := fposmod(float(cloud.x) + float(cloud.speed) * _t - left, room_size.x + w + 32.0) + left
		(cloud.node as Node2D).position = Vector2(x, cloud.y).round()


# ------------------------------------------------------------------ birds ----

## bird.png is two 7x4 frames side by side: wings up, wings down.
func _bird_sheet(sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 5.0)
	var w := sheet.get_width() / 2
	for i in 2:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * w, 0, w, sheet.get_height())
		frames.add_frame(&"default", atlas)
	return frames


## Now and then a few gulls cross, in a loose line, flapping and gliding.
func _fly_birds(delta: float) -> void:
	_next_flock -= delta
	if _next_flock <= 0.0 and _flock.is_empty():
		_next_flock = _rng.randf_range(float(_birds["every"][0]), float(_birds["every"][1]))
		var dir := 1.0 if _rng.randf() < 0.7 else -1.0
		var y := _rng.randf_range(float(_birds["y"][0]), float(_birds["y"][1]))
		var speed := _rng.randf_range(15.0, 22.0)
		for i in _rng.randi_range(1, int(_birds["count"])):
			var bird := AnimatedSprite2D.new()
			bird.sprite_frames = _bird_frames
			bird.centered = false
			bird.z_as_relative = false
			bird.z_index = -11
			bird.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			bird.flip_h = dir < 0.0
			_clip.add_child(bird)
			bird.play()
			var start := Vector2(-12.0 if dir > 0.0 else room_size.x + 12.0, y)
			start += Vector2(-dir * (9.0 * i + _rng.randf_range(0, 4)), (i % 2) * 4.0 - 2.0 + _rng.randf_range(-1, 1))
			_flock.append({node = bird, at = start, v = dir * speed * _rng.randf_range(0.95, 1.05),
				ph = _rng.randf() * TAU})
	for i in range(_flock.size() - 1, -1, -1):
		var b: Dictionary = _flock[i]
		var bird := b.node as AnimatedSprite2D
		b.at += Vector2(b.v * delta, 0.0)
		# Flap for a while, then glide on still wings.
		var flapping := fmod(_t * 0.6 + b.ph, 2.0) < 1.2
		bird.speed_scale = 1.0 if flapping else 0.0
		if not flapping:
			bird.frame = 0
		bird.position = (b.at + Vector2(0, sin(_t * 1.7 + b.ph) * 1.5)).round()
		var bx: float = b.at.x
		if bx < -60.0 or bx > room_size.x + 60.0:
			bird.queue_free()
			_flock.remove_at(i)


# ------------------------------------------------------------------ motes ----

func _add_motes(spec: Dictionary) -> void:
	var amount := int(spec.get("amount", 8))
	# Two in three blow through behind the land, the rest across the front of it.
	var far := Motes.new(self, spec, amount - amount / 3, false, _rng.randi())
	far.z_as_relative = false
	far.z_index = -7
	_clip.add_child(far)
	var near := Motes.new(self, spec, amount / 3, true, _rng.randi())
	near.z_as_relative = false
	near.z_index = 5
	_clip.add_child(near)


## Room y of the ground under room x, or the room's floor where none was painted.
func ground_at(x: float) -> float:
	if ground.is_empty():
		return room_size.y
	return float(ground[clampi(int(x), 0, ground.size() - 1)])


## Seeds, petals, leaves, butterflies and motes of dust, a pixel or two each,
## simulated and drawn here rather than by a particle system so every one lands
## on a whole pixel and keeps to the air above the ground.
class Motes extends Node2D:
	var owner_backdrop: LandBackdrop
	var kind := "seed"
	var colour := Color.WHITE
	var wind := 6.0
	var near := false
	var items: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	var t := 0.0

	func _init(backdrop: LandBackdrop, spec: Dictionary, amount: int, in_front: bool, seed_value: int) -> void:
		owner_backdrop = backdrop
		kind = str(spec.get("kind", "seed"))
		colour = Color(str(spec.get("colour", "#ffffff")))
		wind = float(spec.get("wind", 6.0))
		near = in_front
		rng.seed = seed_value
		if not near:
			colour = colour.darkened(0.12)
			colour.a = 0.75
		for i in amount:
			var m := {}
			_spawn(m, true)
			items.append(m)

	func _spawn(m: Dictionary, anywhere: bool) -> void:
		var size := owner_backdrop.room_size
		var x := rng.randf_range(0.0, size.x)
		m.ph = rng.randf() * TAU
		m.rate = rng.randf_range(0.7, 1.3)
		match kind:
			"petal", "leaf":
				var top := rng.randf_range(-20.0, size.y * 0.5) if anywhere else rng.randf_range(-24.0, -4.0)
				m.at = Vector2(x if anywhere or wind <= 0.0 else rng.randf_range(-40.0, size.x), top)
			"butterfly":
				m.at = Vector2(x, owner_backdrop.ground_at(x) - rng.randf_range(8.0, 30.0))
				m.goal = m.at
				m.wait = 0.0
			_:
				var g := owner_backdrop.ground_at(x)
				m.at = Vector2(x if anywhere else (-4.0 if wind >= 0.0 else size.x + 4.0),
					rng.randf_range(g * 0.25, g - 6.0))

	func _process(delta: float) -> void:
		t += delta
		var size := owner_backdrop.room_size
		for m in items:
			var r: float = m.rate
			match kind:
				"petal", "leaf":
					var swing := 9.0 if kind == "leaf" else 6.0
					m.at += Vector2(wind * r + cos(t * 1.6 * r + m.ph) * swing, (7.0 if kind == "leaf" else 9.0) * r) * delta
					if m.at.y > owner_backdrop.ground_at(m.at.x) or m.at.x > size.x + 8.0 or m.at.x < -48.0:
						_spawn(m, false)
				"butterfly":
					m.wait -= delta
					if m.wait <= 0.0 or (m.at as Vector2).distance_to(m.goal) < 2.0:
						var gx := clampf(m.at.x + rng.randf_range(-50.0, 50.0), 8.0, size.x - 8.0)
						m.goal = Vector2(gx, owner_backdrop.ground_at(gx) - rng.randf_range(6.0, 34.0))
						m.wait = rng.randf_range(2.0, 4.0)
					m.at = (m.at as Vector2).move_toward(m.goal, 11.0 * r * delta) \
						+ Vector2(0, sin(t * 7.0 * r + m.ph) * 6.0 * delta)
				_:
					var lift := -1.5 if kind == "seed" else 0.0
					m.at += Vector2(wind * r + sin(t * 0.7 * r + m.ph) * 3.0,
						lift + sin(t * 0.9 * r + m.ph * 2.0) * 4.0) * delta
					var g := owner_backdrop.ground_at(m.at.x)
					if m.at.x > size.x + 6.0 or m.at.x < -6.0 or m.at.y > g - 2.0 or m.at.y < -6.0:
						_spawn(m, false)
		queue_redraw()

	func _draw() -> void:
		for m in items:
			var p := (m.at as Vector2).round()
			var c := colour
			match kind:
				"petal", "leaf":
					# Tumbling: flat, then edge-on, then flat again.
					var flat := sin(t * 3.0 * m.rate + m.ph) > 0.0
					draw_rect(Rect2(p, Vector2(2, 1) if flat else Vector2(1, 2 if kind == "leaf" else 1)), c)
				"butterfly":
					var open := sin(t * 16.0 * m.rate + m.ph) > 0.0
					draw_rect(Rect2(p, Vector2.ONE), c.darkened(0.5))
					if open:
						draw_rect(Rect2(p + Vector2(-1, -1), Vector2.ONE), c)
						draw_rect(Rect2(p + Vector2(1, -1), Vector2.ONE), c)
					else:
						draw_rect(Rect2(p + Vector2(0, -1), Vector2.ONE), c)
				"mote":
					c.a *= 0.45 + 0.45 * sin(t * 1.3 * m.rate + m.ph)
					draw_rect(Rect2(p, Vector2.ONE), c)
				_:
					draw_rect(Rect2(p, Vector2.ONE), c)
