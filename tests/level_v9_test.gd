extends Node
## Exercise authored jumps with real input, movement, collision and hazards.
## Each leg starts on its actual departure ledge, tries normal jump/dash timings,
## and must finish standing on its destination. No teleporting across a gap.
var failures: Array[String] = []
var world: LdtkWorld
var player: Player
var origin: Vector2
var route := [Vector3(0,320,96), Vector3(120,296,32), Vector3(184,272,32),
	Vector3(248,248,56), Vector3(328,224,24), Vector3(384,208,24),
	Vector3(440,192,72), Vector3(392,160,32), Vector3(344,128,32),
	Vector3(280,96,40), Vector3(368,64,40), Vector3(448,64,32),
	Vector3(520,64,40), Vector3(592,64,48)]

func _ready() -> void:
	SaveGame.slot = -1
	LdtkWorld.debug_start_room = "Level_V9"
	world = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await frames(5)
	player = world.player
	origin = world.current_room.global_position
	check(world.current_room.name == "Level_V9", "debug entry reaches V9")
	check(world._room_before(world.current_room).name == "Level_V8", "V8 leads into V9")
	check(world._room_after(world.current_room).name == "Level_V10", "V9 leads into the new descent")
	# Freeze room transitions for leg trials; all geometry and hazards remain live.
	world.set_physics_process(false)
	player.died.disconnect(world._on_player_died)
	for i in range(route.size()-1):
		var solved := false
		for dash_at in [-1, 8, 12, 16, 20, 24, 4]:
			if await jump_leg(route[i], route[i+1], dash_at):
				print("ROUTE leg %d passed; dash frame %d" % [i+1, dash_at])
				solved = true
				break
		check(solved, "leg %d is traversable using normal movement" % (i+1))
	# Optional fruit alcoves must also be reachable from a permanent landing.
	check(await any_jump(route[6], Vector3(536,160,32)), "right lemon alcove is reachable")
	check(await any_jump(route[9], Vector3(224,72,24)), "left lemon alcove is reachable")
	player.died.connect(world._on_player_died)
	# Checkpoints must survive a real kill and return to their own safe ledge.
	for cp in get_tree().get_nodes_in_group("checkpoint"):
		if not world.current_room.is_ancestor_of(cp): continue
		player.respawn(cp.global_position)
		await frames(5)
		world._on_checkpoint_activated(cp)
		player.die()
		await get_tree().create_timer(0.4).timeout
		await frames(5)
		check(player.global_position.distance_to(cp.global_position) < 12 and player.state_name() != "DEAD", "checkpoint respawn is safe")
	release()
	print("LEVEL V9: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func any_jump(a: Vector3, b: Vector3) -> bool:
	for timing in [-1, 8, 12, 16, 20, 24, 4]:
		if await jump_leg(a, b, timing): return true
	return false

func jump_leg(a: Vector3, b: Vector3, dash_at: int) -> bool:
	release()
	for crumble in get_tree().get_nodes_in_group("crumbling"):
		if world.current_room.is_ancestor_of(crumble): crumble.reset()
	var direction := signf(b.x + b.z / 2 - a.x - a.z / 2)
	var start_x := a.x + a.z - 8 if direction > 0 else a.x + 8
	player.respawn(origin + Vector2(start_x, a.y - 6))
	player.has_dash = true
	await frames(5)
	var target := origin + Vector2(b.x + b.z / 2, b.y - 6)
	for frame in 90:
		var dx := target.x - player.global_position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx) > 2:
			Input.action_press("move_right" if dx > 0 else "move_left")
		if frame == 0: Input.action_press("jump")
		if frame == 14: Input.action_release("jump")
		if frame == dash_at:
			if b.y < a.y: Input.action_press("move_up")
			Input.action_press("dash")
		if frame == dash_at + 1:
			Input.action_release("dash")
			Input.action_release("move_up")
		await frames(1)
		if player.state_name() == "DEAD": break
		if frame > 3 and player.is_on_floor() and absf(player.global_position.y-target.y) < 3 and absf(player.global_position.x-target.x) < b.z/2:
			release()
			return true
	release()
	print("  attempt failed: %s -> %s dash %d; ended %s %s" % [a,b,dash_at,player.global_position-origin,player.state_name()])
	return false

func release() -> void:
	for action in ["move_left","move_right","move_up","jump","dash"]: Input.action_release(action)
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures.append(message)
