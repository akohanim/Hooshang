extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func _ready() -> void:
	var player: Player = preload("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.position = Vector2(160,100)
	player.camera.position_smoothing_enabled = false
	player.camera.make_current()
	player.camera.force_update_scroll()
	var boss: Darkshang = preload("res://scenes/props/chase/Darkshang.tscn").instantiate()
	boss.auto_start = false
	add_child(boss)
	boss.set_physics_process(false)
	boss.buffer.set_physics_process(false)
	boss.entry_room_bounds = Rect2(-1000,-1000,3000,3000)
	boss._player = player
	boss._visual.cloud_form = true
	boss.start_chase()
	for i in 20:
		player.position.x -= 8
		player.camera.force_update_scroll()
		boss._physics_process(.016)
		check(boss.position.is_equal_approx(boss.charge_hover_position()), "idle cloud stays at camera right while scrolling")
		var screen_rect: Rect2 = boss.get_viewport().get_canvas_transform().affine_inverse() * boss.get_viewport_rect()
		var cloud_node: Node2D = boss._visual.get_node("Body/Cloud")
		var cloud_rect: Rect2 = cloud_node.global_transform * Rect2(-36,-62,72,76)
		check(screen_rect.encloses(cloud_rect), "whole waiting cloud stays on screen")
	var view := boss.charge_view_rect()
	boss.position = view.position+view.size*Vector2(.6,.5)
	boss._tick_power_entry(.5)
	var start := boss.position
	check(boss.locked_charge(.6,240,160,.8),"charge starts staged approach")
	check(boss.position == start,"starting charge does not teleport")
	boss._physics_process(.016)
	check(absf(boss.position.x-start.x) < 3 and boss.position.y == player.position.y,"approach eases horizontally at player height")
	for i in 28: boss._physics_process(.016)
	check(boss._locked_charge.phase == 1,"approach finishes before full warning begins")
	check(boss.position.x > boss.charge_view_rect().end.x-16,"warning floats on right edge of visible camera")
	var snapshot: Vector2 = boss._locked_charge.locked_target
	var in_view := true
	var aligned := true
	for i in 20:
		player.position += Vector2(-2,1)
		player.camera.force_update_scroll()
		boss._physics_process(.016)
		in_view = in_view and boss.charge_view_rect().has_point(boss.position)
		aligned = aligned and is_equal_approx(boss.position.y,player.position.y) and boss._locked_charge.direction == Vector2.LEFT
	check(in_view,"camera movement keeps entire warning inside safe screen inset")
	check(aligned,"pre-charge follows player height with a horizontal warning")
	check(boss._locked_charge.locked_target == player.position,"pre-charge tracks current player position until launch")
	check(boss._visual._humanoid, "transformation begins during the warning before launch")
	boss._physics_process(.3)
	check(boss._locked_charge.phase == 2,"full warning releases charge")
	var origin := boss.position
	var aim: Vector2 = boss._locked_charge.direction
	check(aim == Vector2.LEFT and origin.y == player.position.y,"launch locks a horizontal lane at latest player height")
	player.position = snapshot+Vector2(0,200)
	boss._physics_process(.1)
	check(boss.position.is_equal_approx(origin+aim*24),"charge stays horizontal after player changes height")
	boss._physics_process(10)
	check(boss._locked_charge.phase == 3,"miss begins recovery")
	var far := boss.position
	check(not boss._visual.visible, "Darkshang disappears at the end of a missed charge")
	check(not boss.powers_available(), "hidden recovery cannot cast another attack")
	boss._physics_process(.4)
	check(boss.position == far and not boss._visual.visible, "no visible return flight during recovery")
	player.position += Vector2(-80,20)
	boss._physics_process(.41)
	check(boss.position.is_equal_approx(origin), "reappears at the original charge launch point")
	check(boss._visual.visible and boss._visual._cloud_weight == 1.0, "reappears fully in cloud form")
	boss._physics_process(.016)
	check(boss.position.is_equal_approx(boss.charge_hover_position()),"returned cloud resumes its visible right-edge waiting position")
	boss._locked_charge.phase = 3
	boss._push_visual()
	check(not boss._visual.visible, "second recovery hides the visual")
	boss.reset_to_checkpoint(player.position)
	check(boss._visual.visible and boss._locked_charge.phase == 0, "checkpoint reset clears recovery hiding")
	print("CLOUD RETURN: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
