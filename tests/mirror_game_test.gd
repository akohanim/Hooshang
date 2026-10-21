extends Node
const MirrorGame = preload("res://scenes/minigame/mirror_game.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print("  PASS " if ok else "  FAIL ", label)
	if not ok: failures += 1

func static_route_exists(game: Node) -> bool:
	# A coarse player-centre search proves the authored geometry does not seal
	# any stage. Moving threats can be dodged or waited out.
	var frontier: Array[Vector2i] = [Vector2i(17, 89)]
	var seen := {frontier[0]: true}
	var head := 0
	while head < frontier.size():
		var here := frontier[head]
		head += 1
		if Vector2(here).distance_to(MirrorGame.GOAL) < 10.0: return true
		for direction in [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4)]:
			var next: Vector2i = here + direction
			if next.x < 8 or next.x > 152 or next.y < 21 or next.y > 105 or seen.has(next): continue
			if game._hits_wall(Vector2(next)): continue
			var safe := true
			for shard: Vector2 in game.STAGES[game.stage].shards:
				if Vector2(next).distance_to(shard) < 7.0: safe = false
			if not safe: continue
			seen[next] = true
			frontier.append(next)
	return false

func _ready() -> void:
	SaveGame.unbind()
	Collectibles.reset()
	var game = MirrorGame.new()
	add_child(game)
	game.activate()
	check(game.mode == MirrorGame.Mode.TITLE and game.stage == 0, "new game opens on the mirror title")
	game.mode = MirrorGame.Mode.STAGE
	var wins := [0]
	game.finished.connect(func(): wins[0] += 1)
	for level in 5:
		check(game.stage == level, "entered stage %d" % (level + 1))
		check(game._first_person() == (level >= 3), "stage %d uses the intended camera" % (level + 1))
		check(not game._hits_wall(MirrorGame.START), "stage %d has a safe start" % (level + 1))
		check(static_route_exists(game), "stage %d has a traversable route through its walls and fixed shards" % (level + 1))
		game.reflection = game.STAGES[level].shards[0]
		game._tick_stage(0.0)
		check(game.deaths == level + 1 and game.stage == level, "stage %d hazard retries locally" % (level + 1))
		game.reflection = MirrorGame.GOAL
		game._tick_stage(0.0)
		if level < 4: check(game.mode == MirrorGame.Mode.BETWEEN, "stage %d leads to an interlude" % (level + 1))
		game.mode = MirrorGame.Mode.STAGE
	game.stage = 3
	Input.action_press("move_up")
	check(game._movement_axis().x > 0.0 and game._movement_axis().y == 0.0, "first-person Up advances toward adult Hooshang")
	Input.action_release("move_up")
	Input.action_press("move_right")
	check(game._movement_axis().y > 0.0 and game._movement_axis().x == 0.0, "first-person Right strafes")
	Input.action_release("move_right")
	game.mode = MirrorGame.Mode.REUNION
	game.mode_time = 2.5
	game._physics_process(0.0)
	check(wins[0] == 1 and not game.active, "final reunion emits one clear")
	game._physics_process(0.1)
	check(wins[0] == 1, "clear cannot emit twice")
	game.queue_free()
	await get_tree().process_frame
	var world = load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room = "Prison_Hub"
	world.get_node("CellReunion").free()
	add_child(world)
	await get_tree().physics_frame
	var tv: RetroTV = world.current_room.get_node("RetroTV")
	check(tv != null and tv.game is MirrorGame, "prison hub installs mirror game on first TV")
	var before := Collectibles.total
	tv._play()
	await get_tree().create_timer(1.55).timeout
	check(tv._playing and world.player.input_locked, "TV push-in hands control to the game")
	var awards: Array[int] = []
	Collectibles.changed.connect(func(total: int) -> void:
		if total > before: awards.append(total))
	tv.game.finished.emit()
	check(Collectibles.total == before, "no lemons bank before they leave the TV")
	tv.game.finished.emit()
	await get_tree().create_timer(1.25).timeout
	check(world.current_room.has_node("RetroTV") and world.player.input_locked, "TV remains during the payout")
	check(tv.get_node_or_null("MirrorRewardLemon") is Node2D, "visible lemon is travelling out of the TV")
	await get_tree().create_timer(3.8).timeout
	check(awards == [before + 1, before + 2, before + 3, before + 4, before + 5], "five lemons land one by one")
	check(Collectibles.total == before + 5, "repeated clear cannot farm lemons")
	check(bool(world.save_state().act2_story.get("mirror_game_cleared", false)), "completion belongs to saved Act 2 story flags")
	check(int(world.save_state().act2_story.get("mirror_reward_count", 0)) == 5, "all five payouts are saved")
	for i in 5: check(Collectibles.is_taken("res://ldtk/Act2World.tscn@mirror_game_%d" % i), "reward %d has a persistent collectible ID" % (i + 1))
	check(not world.current_room.has_node("RetroTV") and not world.player.input_locked, "TV disappears after pull-out and control returns")
	var saved_world: Dictionary = world.save_state()
	var saved_lemons: Dictionary = Collectibles.save_state()
	world.queue_free()
	await get_tree().process_frame
	SaveGame._pending = {"world_state": saved_world}
	Collectibles.reset()
	Collectibles.load_state(saved_lemons)
	var loaded = load("res://ldtk/Act2World.tscn").instantiate()
	loaded.debug_start_room = "Prison_Hub"
	loaded.get_node("CellReunion").free()
	add_child(loaded)
	await get_tree().physics_frame
	check(not loaded.current_room.has_node("RetroTV"), "completed TV stays absent after a world reload")
	check(Collectibles.total == before + 5, "all five lemons survive save restoration")
	loaded.queue_free()
	await get_tree().process_frame
	var partial_world: Dictionary = saved_world.duplicate(true)
	partial_world.act2_story.mirror_reward_count = 2
	SaveGame._pending = {"world_state": partial_world}
	Collectibles.reset()
	Collectibles.load_state({"total": before + 2, "taken": [
		"res://ldtk/Act2World.tscn@mirror_game_0",
		"res://ldtk/Act2World.tscn@mirror_game_1"]})
	var resumed = load("res://ldtk/Act2World.tscn").instantiate()
	resumed.debug_start_room = "Prison_Hub"
	resumed.get_node("CellReunion").free()
	add_child(resumed)
	await get_tree().physics_frame
	check(resumed.current_room.has_node("RetroTV"), "a partial payout restores the TV until the remaining lemons arrive")
	await get_tree().create_timer(3.1).timeout
	check(Collectibles.total == before + 5 and not resumed.current_room.has_node("RetroTV"), "reload resumes only the remaining three lemons, then removes the TV")
	resumed.queue_free()
	SaveGame.unbind()
	await get_tree().process_frame
	print("MIRROR GAME: ", failures, " failures")
	get_tree().quit(1 if failures else 0)
