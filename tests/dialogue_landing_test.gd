extends Node
var failures: Array[String] = []
var player: Player

func _ready() -> void:
	SaveGame.slot = -1
	var world := Node2D.new()
	Screen.set_scene(world)
	var floor_body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(320, 16)
	collision.shape = shape
	floor_body.position = Vector2(160, 152)
	floor_body.add_child(collision)
	world.add_child(floor_body)
	player = preload("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	player.position = Vector2(100, 70)
	world.add_child(player)
	await frames(2)
	player.has_dash = true
	player._try_dash(Vector2.RIGHT)
	Dialogue.begin_conversation(self, player)
	Dialogue.say("Test", "Feet on the floor.")
	check(not Dialogue._active, "speech waits for landing")
	var origin := player.position
	for i in 120:
		await frames(1)
		if Dialogue._active:
			break
	check(Dialogue._active and player.is_on_floor(), "speech opens on real floor contact")
	check(player.position.y > origin.y + 20 and absf(player.position.x - origin.x) < 0.01,
		"arrival falls onto floor without dash drift or teleport")
	check(player.state == Player.State.IDLE and player.visual.animation == &"idle", "grounded idle pose")
	var at := player.position
	await frames(20)
	check(player.position.is_equal_approx(at), "grounded during speech")
	Dialogue.line_finished.emit()
	Dialogue.end_conversation()
	await frames(35)
	check(player.state != Player.State.DASH and player.is_on_floor(), "old dash never resumes")
	# Cancel while landing and begin again on the SAME player. The old waiter
	# must not move or unlock the new conversation.
	player.global_position = Vector2(100, 50)
	player.state = Player.State.FALL
	player.velocity = Vector2.DOWN
	player.move_and_slide()
	Dialogue.begin_conversation(self, player)
	Dialogue.say("Old", "Canceled.")
	Dialogue.end_conversation()
	player.freeze()
	var canceled_at := player.position
	await frames(4)
	check(player.position.is_equal_approx(canceled_at), "canceled landing cannot move the player")
	player.unfreeze()
	print("DIALOGUE LANDING: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures.append(message)
