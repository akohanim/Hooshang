extends Node2D
## Original procedural art; motion measured from the installed Celeste DustGraphic.
## The mask is presentation only. ThoughtHazards remains the editable collision map.

## Angular speed of the counter-rotating outer tufts (radians per second).
@export var lobe_speed := 0.5
## Angular speed of the central tuft (radians per second).
@export var center_speed := 0.6
## Speed at which the eyes approach their target direction.
@export var eye_turn_speed := 12.0

var elapsed := 0.0
var eyes: Array[Dictionary] = []
var _player: Node2D
var _body_material: ShaderMaterial

func configure(layer: TileMapLayer) -> void:
	var bounds := layer.get_used_rect().grow(1)
	position = Vector2(bounds.position * 8)
	var mask := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	eyes.clear()
	for cell in layer.get_used_cells():
		var local := cell - bounds.position
		mask.set_pixelv(local, Color.WHITE)
		var seed := ThoughtHazardLayer._hash(cell + Vector2i(53, 97))
		# Half have eyes; thirty percent of those follow the player.
		if seed < 0.5:
			var phase := ThoughtHazardLayer._hash(cell + Vector2i(131, 17))
			eyes.append({"position": Vector2(local * 8) + Vector2(4, 4),
				"direction": Vector2.from_angle(phase * TAU), "follow": seed < 0.15,
				"period": 2.0 + phase * 1.5 + 0.25 + 0.02 + phase * 0.05, "phase": seed * 7.0,
				"lag": 0.02 + phase * 0.05})
	$Body.texture = ImageTexture.create_from_image(mask)
	_body_material = $Body.material
	_body_material.set_shader_parameter("occupancy", $Body.texture)
	_body_material.set_shader_parameter("grid_size", Vector2(bounds.size))
	_body_material.set_shader_parameter("grid_origin", Vector2(bounds.position))
	_body_material.set_shader_parameter("lobe_speed", lobe_speed)
	_body_material.set_shader_parameter("center_speed", center_speed)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat

func _process(delta: float) -> void:
	elapsed += delta
	if _body_material == null:
		return
	_body_material.set_shader_parameter("clock", elapsed)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(_player):
		for eye in eyes:
			if eye.follow:
				var target := (to_local(_player.global_position) - Vector2(eye.position)).normalized()
				eye.direction = Vector2(eye.direction).move_toward(target, eye_turn_speed * delta)
	queue_redraw()

func eye_visibility(eye: Dictionary) -> Vector2i:
	var t := fposmod(elapsed + float(eye.phase), float(eye.period))
	var start := float(eye.period) - 0.25 - float(eye.lag)
	return Vector2i(int(t < start), int(t < start + float(eye.lag)))

func _draw() -> void:
	for eye in eyes:
		var open := eye_visibility(eye)
		var direction: Vector2 = eye.direction
		var side := Vector2(-direction.y, direction.x).normalized()
		var center: Vector2 = eye.position + direction * 1.4
		for i in 2:
			if open[i]:
				var at := (center + side * (-1.0 if i == 0 else 1.0)).floor()
				draw_rect(Rect2(at, Vector2.ONE), Color("ffb09b"))
