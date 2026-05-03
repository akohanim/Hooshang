extends Node2D
## Level 5 — Executive Override
##
## Requires mastery of BOTH standard dashes AND the Document Floater paper-trail dash.
##
## Section 1 – Gauntlet:  three thin platforms demanding precise diagonal dashes.
## Section 2 – Canyon:    a 250 px gap that punishes mistimed jumps; DocFloater1 bridges it.
## Section 3 – The Ascent: VertBase → ClimbTop is 282 px straight up — beyond the max
##                          jump+dash reach of 266 px.  The only way is a paper staircase:
##                          dash straight up → three platforms stack below → land → dash resets
##                          → jump to ClimbTop.
## Section 4 – Apex Run:  water-cooler dash refresh + DocFloater3 for the final approach.

const DEATH_Y   := 460.0
const SPAWN_POS := Vector2(100.0, 325.0)

@onready var _player : CharacterBody2D = $Player
@onready var _camera : Camera2D        = $Camera2D
@onready var _goal   : Area2D          = $GoalZone
@onready var _s1     : Node2D          = $Shredder1
@onready var _s2     : Node2D          = $Shredder2
@onready var _s3     : Node2D          = $Shredder3
@onready var _s4     : Node2D          = $Shredder4

var _dying := false


func _ready() -> void:
	_camera.call("configure_limits", -50, -300, 1950, 500)
	_camera.global_position = SPAWN_POS
	_camera.set("target", _player)
	_goal.body_entered.connect(_on_goal_entered)
	_s1.player_hit.connect(_die)
	_s2.player_hit.connect(_die)
	_s3.player_hit.connect(_die)
	_s4.player_hit.connect(_die)


func _process(_delta: float) -> void:
	if not _dying and _player.global_position.y > DEATH_Y:
		_die()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Engine.time_scale = 1.0
		_cleanup_paper()
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


# ── Death / respawn ────────────────────────────────────────────────────────────

func _die() -> void:
	if _dying:
		return
	_dying = true
	Engine.time_scale = 1.0
	_player.velocity  = Vector2.ZERO
	_player.set_physics_process(false)
	_cleanup_paper()

	var spr := _player.get_node_or_null("Sprite2D") as Sprite2D
	if spr:
		spr.modulate = Color(1.2, 0.15, 0.15, 1.0)

	await get_tree().create_timer(0.50).timeout

	_player.global_position = SPAWN_POS
	_player.velocity         = Vector2.ZERO
	_camera.global_position  = SPAWN_POS
	_player.set_physics_process(true)

	if spr:
		spr.modulate = Color(2.5, 2.5, 2.5, 1.0)
	await get_tree().create_timer(0.10).timeout
	if spr:
		spr.modulate = Color(1.0, 1.0, 1.0, 1.0)

	_dying = false


func _cleanup_paper() -> void:
	for node in get_children():
		if node.get_script() != null:
			var path : String = node.get_script().resource_path
			if path.ends_with("paper_platform.gd"):
				node.queue_free()


func _on_goal_entered(body: Node2D) -> void:
	if body == _player:
		get_tree().change_scene_to_file.call_deferred("res://scenes/MainMenu.tscn")
