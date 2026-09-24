extends Node
const PLAYER := preload("res://scenes/characters/hooshang/Hooshang.tscn")
var failures: Array[String] = []
var world: Node2D
var player: Player

func _ready() -> void:
	SaveGame.slot = -1
	for dir in [1, -1]:
		await _setup(dir)
		player.position = Vector2(100 - dir * 6.5, 82) # feet exactly 8 below top
		_check(player._try_ledge_mantle(dir), "exactly 8px catches, direction %d" % dir)
		_check(player.state == Player.State.LEDGE_MANTLE, "commits mantle")
		await _finish(dir)
		_check(player.is_on_floor() and player.position.y < 75, "settles on floating platform")
		_check(player.state in [Player.State.IDLE, Player.State.RUN], "no falling-pose flash after completion")
		_check(player.dash_available, "standing restores dash")
		await _setup(dir)
		player.position = Vector2(100-dir*6.5,82.2)
		_check(not player._try_ledge_mantle(dir), "8.2px miss stays a miss")
		player.position = Vector2(100-dir*8,80)
		_check(not player._try_ledge_mantle(dir), "horizontal gap beyond 3px refused")
		player.position = Vector2(100-dir*6.5,80)
		_check(not player._try_ledge_mantle(-dir), "steering away never catches")
		player.velocity.y = -100
		_check(not player._try_ledge_mantle(dir), "healthy rising jump preserves its arc")
		player.velocity.y = 0
		Input.action_press("move_down")
		_check(not player._try_ledge_mantle(dir), "deliberate drop refused")
		Input.action_release("move_down")
		player.input_locked = true
		_check(not player._try_ledge_mantle(dir), "locked controls refused")
		player.input_locked = false
		player.squeezing = true
		_check(not player._try_ledge_mantle(dir), "chimney squeeze refused")
	await _setup(1)
	_body(Rect2(88,61,30,8))
	await _frames(2)
	_check(not player._try_ledge_mantle(1), "low ceiling blocks the full rise path")
	await _setup(1, true)
	_check(player._try_ledge_mantle(1), "real TileMapLayer collision accepted")
	await _finish(1)
	_check(player.is_on_floor(), "lands on actual collision tiles")
	await _setup(1)
	player.state = Player.State.DASH
	player.dash_dir = Vector2.RIGHT
	player.dash_timer = 0.1
	player.dash_available = false
	_check(player._try_ledge_mantle(0), "committed horizontal dash catches without held input")
	_check(player.dash_timer == 0 and not player.dash_available, "dash cancels but no midair refill")
	await _finish(1)
	_check(player.dash_available, "dash refills after planting")
	await _setup(1)
	_check(player._try_ledge_mantle(1), "removed support case begins")
	world.get_node("Platform").queue_free()
	await _frames(2)
	await _finish(1)
	_check(player.state == Player.State.FALL, "removed platform gives control back to gravity")
	await _setup(1)
	player._try_ledge_mantle(1)
	player.respawn(Vector2(30,30))
	_check(player.state == Player.State.FALL and player._ledge_elapsed == 0, "respawn clears mantle")
	_check(player.visual.sprite_frames.has_animation("ledge_climb"), "Aseprite clip exported")
	_check(player.visual.sprite_frames.get_frame_count("exit_water") == 6, "appending Aseprite clip preserves original water tag")
	_check(player.visual.sprite_frames.get_frame_count("ledge_climb") == 6, "new climb has six poses")
	var child: SpriteFrames = load("res://assets/characters/hooshang_child/act2_frames.tres")
	_check(child.has_animation("ledge_climb") and child.get_frame_count("ledge_climb") == 6, "child has dedicated upright pull-up")
	_check(not child.get_animation_loop("ledge_climb"), "child pull-up is a one-shot")
	_check(child.get_meta("sock_pixels")["ledge_climb"].size() == 6, "child ankle marks follow every pull-up pose")
	print("LEDGE MANTLE: %d failures" % failures.size())
	for failure in failures: push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func _setup(dir: int, tiles := false) -> void:
	Input.action_release("move_right")
	Input.action_release("move_left")
	if world: world.queue_free(); await _frames(2)
	world = Node2D.new()
	add_child(world)
	if tiles:
		var layer := TileMapLayer.new()
		var tileset := TileSet.new()
		tileset.tile_size = Vector2i(8,8)
		tileset.add_physics_layer()
		tileset.set_physics_layer_collision_layer(0,1)
		var atlas := TileSetAtlasSource.new()
		atlas.texture = ImageTexture.create_from_image(Image.create(8,8,false,Image.FORMAT_RGBA8))
		atlas.texture_region_size = Vector2i(8,8)
		atlas.create_tile(Vector2i.ZERO)
		tileset.add_source(atlas,0)
		var data := atlas.get_tile_data(Vector2i.ZERO,0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-4,-4),Vector2(4,-4),Vector2(4,4),Vector2(-4,4)]))
		layer.tile_set = tileset
		layer.position = Vector2(100,80)
		for x in 4: layer.set_cell(Vector2i(x,0),0,Vector2i.ZERO)
		world.add_child(layer)
	else:
		_body(Rect2(100 if dir==1 else 92,80,8,8))
	player = PLAYER.instantiate()
	player.position = Vector2(100-dir*6.5,80)
	world.add_child(player)
	player.camera.enabled = false
	player.set_physics_process(false)
	player.state = Player.State.FALL
	player.has_dash = true
	player.dash_available = false
	await _frames(3)

func _finish(dir: int) -> void:
	var action := "move_right" if dir==1 else "move_left"
	Input.action_press(action)
	for frame in 30:
		player._physics_process(1.0/60)
		await get_tree().physics_frame
		if player.state != Player.State.LEDGE_MANTLE: break
	Input.action_release(action)

func _body(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = "Platform"
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = rect.size
	body.add_child(shape)
	world.add_child(body)

func _frames(n: int) -> void:
	for i in n: await get_tree().physics_frame

func _check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures.append(message)
