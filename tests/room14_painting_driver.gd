extends RefCounted
## Drive real input in the painting break; never teleport or stamp marks directly.
static func set_action(action: String, pressed: bool) -> void:
	if pressed and not Input.is_action_pressed(action): Input.action_press(action)
	elif not pressed and Input.is_action_pressed(action): Input.action_release(action)

static func release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump", "dash", "glow"]:
		Input.action_release(action)

static func drive(story: Node, finish := true) -> void:
	var game: Node = story.painting_game
	var x: float = story.to_local(story.world.player.global_position).x
	for action in ["move_left", "move_right", "move_up", "move_down"]: set_action(action, false)
	# Give C/X a full release frame between deliberate button presses.
	if Input.is_action_pressed("jump") or Input.is_action_pressed("dash"):
		set_action("jump", false)
		set_action("dash", false)
		return
	var desired := -1
	for color in 3:
		var count := 0
		for mark: Dictionary in story.get_node("Wall/Graffiti").paint_marks:
			if mark.color == color: count += 1
		if count < 8:
			desired = color
			break
	if game.has_can and game.color_index == desired:
		if not game.painting: set_action("dash", true)
		else: set_action("move_up", true)
		return
	if game.painting:
		set_action("dash", true)
		return
	if game.has_can and desired >= 0:
		set_action("jump", true)
		return
	var target: float = story.cousin.position.x if desired < 0 else story.to_local(game._ground_cans[desired].global_position).x
	set_action("move_left", x > target + 3)
	set_action("move_right", x < target - 3)
	if desired >= 0 and absf(x - target) < 9:
		set_action("jump", true)
	if desired < 0 and finish and absf(x - target) < 18:
		set_action("move_down", true)
