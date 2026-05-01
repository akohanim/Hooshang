extends Node2D

# ── Level config ───────────────────────────────────────────────────────────────
const DEATH_Y   := 460.0               # y below which the player dies
const SPAWN_POS := Vector2(110.0, 274.0)  # on top of the start platform

@onready var _player : CharacterBody2D = $Player
@onready var _camera : Camera2D        = $Camera2D
@onready var _goal   : Area2D          = $GoalZone

var _dying := false


func _ready() -> void:
	_camera.call("configure_limits", -50, -300, 1900, 510)
	_camera.global_position = SPAWN_POS
	_camera.set("target", _player)
	_goal.body_entered.connect(_on_goal_entered)


func _process(_delta: float) -> void:
	if not _dying and _player.global_position.y > DEATH_Y:
		_die()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


# ── Death & respawn ───────────────────────────────────────────────────────────

func _die() -> void:
	_dying = true
	Engine.time_scale = 1.0
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(false)

	var spr := _player.get_node_or_null("Sprite2D") as Sprite2D
	if spr:
		spr.modulate = Color(1.2, 0.15, 0.15, 1.0)  # flash red

	await get_tree().create_timer(0.50).timeout

	# Teleport & snap camera
	_player.global_position = SPAWN_POS
	_player.velocity         = Vector2.ZERO
	_camera.global_position  = SPAWN_POS
	_player.set_physics_process(true)

	# Brief white flash on respawn
	if spr:
		spr.modulate = Color(2.5, 2.5, 2.5, 1.0)
	await get_tree().create_timer(0.10).timeout
	if spr:
		spr.modulate = Color(1.0, 1.0, 1.0, 1.0)

	_dying = false


func _on_goal_entered(body: Node2D) -> void:
	if body == _player:
		get_tree().change_scene_to_file.call_deferred("res://scenes/MainMenu.tscn")
