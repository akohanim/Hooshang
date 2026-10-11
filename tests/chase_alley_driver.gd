extends Node
## Input-only alley traversal. Stable takeoffs avoid accidentally wall-jumping
## when small differences in arrival timing put the player against a riser.
var world: Node
var failure := ""
var deaths := 0
var assisted := false
var before_exit := Callable()
func tick() -> void:
	await get_tree().physics_frame
	assisted = assisted or world.player.state_name() in ["CLIMB","LEDGE_MANTLE"]
func release() -> void:
	for action in ["move_left","move_right","jump","dash"]: Input.action_release(action)
func local_x() -> float:
	return world.player.global_position.x - world.current_room.global_position.x
func traverse() -> bool:
	world.player.died.connect(on_death)
	for i in 240:
		if not world._transitioning and not world.player.input_locked and world.player.is_on_floor(): break
		await tick()
	for step in [Vector2(176,208),Vector2(256,288),Vector2(408,440),Vector2(480,512)]:
		if not await approach(step.x): break
		Input.action_press("move_right")
		Input.action_press("jump")
		var landed := false
		for i in 150:
			await tick()
			if i > 8 and local_x() >= step.y and world.player.is_on_floor():
				landed = true
				break
		release()
		for i in 24: await tick()
		if not landed:
			failure = "jump did not reach alley bank " + str(step.y)
			break
		print("ALLEY BANK ",step.y," actual=",local_x())
	if failure == "":
		if before_exit.is_valid(): await before_exit.call()
		Input.action_press("move_right")
		for i in 300:
			await tick()
			if str(world.current_room.name) == "Act_2_Level_18": break
		release()
		for i in 240:
			await tick()
			if not world._transitioning and not world.player.input_locked and world.player.is_on_floor(): break
		if str(world.current_room.name) != "Act_2_Level_18": failure = "alley exit did not reach pond"
	release()
	world.player.died.disconnect(on_death)
	print("ALLEY INPUT ","PASS" if failure=="" and deaths==0 and not assisted else "FAIL", " deaths=",deaths," assisted=",assisted," ",failure)
	return failure=="" and deaths==0 and not assisted
func approach(target: float) -> bool:
	for i in 500:
		var dx := target - local_x()
		var vx: float = world.player.velocity.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx) < 3 and absf(vx) < 4 and world.player.is_on_floor(): return true
		var braking: float = vx * vx / (2 * world.player.ground_decel) + 1
		if signf(vx) != signf(dx) or absf(dx) > braking:
			Input.action_press("move_right" if dx > 0 else "move_left")
		await tick()
	failure = "could not approach alley takeoff " + str(target)
	release()
	return false
func on_death() -> void: deaths += 1
