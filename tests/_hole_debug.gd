extends Node
var world: LdtkWorld
var player: Player
func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
func _ready() -> void:
	world = load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await _frames(10)
	player = world.player
	for r in world.rooms:
		if r.name == "Level_2":
			world.current_room = r
	var holes: Array[float] = [124.0, 148.0]
	for cx: float in holes:
		print("---- Level_2 platform gap centre x=%.1f, top y=248 ----" % cx)
		var caught := 0
		var slides := 0
		for i in 17:
			# Park him on solid ground and let any pending respawn resolve, so
			# one trial cannot leak into the next.
			player.input_locked = false
			player.velocity = Vector2.ZERO
			player.respawn(Vector2(100.0, 241.0))
			await _frames(20)
			var dx: float = -3.5 + 7.0 * float(i) / 16.0
			player.input_locked = false
			player.velocity = Vector2.ZERO
			player.respawn(Vector2(cx + dx, 241.0))
			var slid := false
			var deepest := 241.0
			for f in 40:
				await _frames(1)
				player.input_locked = false
				deepest = maxf(deepest, player.global_position.y)
				if player.state == Player.State.WALL_SLIDE:
					slid = true
			var went: bool = deepest > 248.0 + 16.0
			if went:
				caught += 1
			if slid:
				slides += 1
			print("   dx=%+.2f -> deepest y=%.1f in=%s slid=%s" % [dx, deepest, went, slid])
		print("  ENTERED %d of 17, wall-slid %d of 17" % [caught, slides])
	get_tree().quit(0)
