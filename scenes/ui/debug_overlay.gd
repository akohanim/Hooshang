extends CanvasLayer
## F3 debug overlay: live view of the player's physics state and feel timers.

@onready var label: Label = $Label

var player: Player


func _ready() -> void:
	visible = false  # start hidden; F3 toggles
	player = get_tree().get_first_node_in_group("player")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible or player == null:
		return
	# World position first: it is what you need when placing lights, props or
	# LDtk entities by hand — walk to the spot and read the number off.
	label.text = "pos   %4.0f, %4.0f\nvel   %4.0f, %4.0f\nstate %s\ndash  %s  (cd %.2f)\ncoyote %.2f  wall %.2f\nbuffer %.2f\nfloor %s  wall %s" % [
		player.global_position.x, player.global_position.y,
		player.velocity.x, player.velocity.y,
		player.state_name(),
		"READY" if player.dash_available else "spent", player.dash_cooldown_timer,
		player.coyote_timer, player.wall_coyote_timer,
		player.jump_buffer_timer,
		player.is_on_floor(), player.is_on_wall(),
	]
