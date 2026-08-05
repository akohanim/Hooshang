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
var _exiting := false

@onready var player: Player = $Player


func _ready() -> void:
	current_checkpoint = $SpawnPoint.global_position
	player.set_camera_limits(camera_limits)
	player.died.connect(_on_player_died)
	for cp in get_tree().get_nodes_in_group("checkpoint"):
		cp.activated.connect(_on_checkpoint_activated)
	# Tell the progression system which level this is (banks it as a checkpoint),
	# and wire every exit sign so walking through one advances to the next level.
	Game.set_current(scene_file_path)
	for ex in get_tree().get_nodes_in_group("exit"):
		ex.body_entered.connect(_on_exit_reached)


## An exit sign doubles as the level-to-level checkpoint: pass through it and the
## game moves on (Celeste-style), never sending you back through this level.
func _on_exit_reached(body: Node2D) -> void:
	if body != player or _exiting:
		return
	_exiting = true
	player.input_locked = true  # freeze during the fade-out
	Game.advance()


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


## Hold long enough for the death animation to play, then put him back.
##
## maxf, not either number alone: `death_time` belongs to dying and is the same
## everywhere, `respawn_delay` belongs to this level and may want to be longer.
## Taking the larger means a level can never cut the burst off half way.
func _on_player_died() -> void:
	await get_tree().create_timer(maxf(respawn_delay, player.death_time)).timeout
	player.respawn(current_checkpoint)
