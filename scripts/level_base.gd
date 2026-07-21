class_name LevelBase
extends Node2D
## Base level controller: camera bounds, checkpoints, kill plane, fast respawn.
## Real levels (see level1_office.gd) extend this and add their own scripting.
##
## FUTURE HOOKS (do not implement yet):
## - Underworld palette shift: tween $CanvasModulate.color here. All level
##   tinting goes through that one node so a palette swap is a single change.
## - Underworld "stayed too long" death timer: run it here and call
##   player.die() when it expires.
## - B&W power mode: also a $CanvasModulate (or shader) change, plus a player
##   state — see player.gd.
## - Musical tile puzzles: add a sibling TileMapLayer + a conductor node here.

## Camera is clamped to this rectangle (pixels) so it never shows outside the level.
@export var camera_limits := Rect2i(0, 0, 2416, 368)
## Falling below this y kills the player (bottomless pits).
@export var kill_y := 400.0
## Delay between death and respawn. Kept tiny for a Celeste-fast retry loop.
@export var respawn_delay := 0.15

var current_checkpoint := Vector2.ZERO

@onready var player: Player = $Player


func _ready() -> void:
	current_checkpoint = $SpawnPoint.global_position
	player.set_camera_limits(camera_limits)
	player.died.connect(_on_player_died)
	for cp in get_tree().get_nodes_in_group("checkpoint"):
		cp.activated.connect(_on_checkpoint_activated)


func _physics_process(_delta: float) -> void:
	if player.state != Player.State.DEAD and player.global_position.y > kill_y:
		player.die()


func _unhandled_input(event: InputEvent) -> void:
	# R = instant retry from the last checkpoint.
	if event.is_action_pressed("respawn") and player.state != Player.State.DEAD \
			and not player.input_locked:  # no suicides mid-cutscene
		player.die()


func _on_checkpoint_activated(cp: Checkpoint) -> void:
	current_checkpoint = cp.global_position
	for c in get_tree().get_nodes_in_group("checkpoint"):
		c.is_active = c == cp


func _on_player_died() -> void:
	await get_tree().create_timer(respawn_delay).timeout
	player.respawn(current_checkpoint)
