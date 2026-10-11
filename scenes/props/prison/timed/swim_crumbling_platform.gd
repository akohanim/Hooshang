@tool
extends CrumblingPlatform
## Existing crumble stones; a safe return to water restores this local attempt.
@export var kind := "SwimCrumblingPlatform"
var mission: Node

func bind(world: Node) -> void:
	mission = world

func refresh() -> void:
	pass

func _process(delta: float) -> void:
	# Landing from water plays an uninterruptible 0.5s animation. Give the
	# swimmer the normal crumble window once movement controls return.
	if mission != null and mission.current_room == get_parent().get_parent():
		var player: Player = mission.player
		if player.state == Player.State.EXIT_WATER and _players_on_skin().has(player) and _standing_on(player):
			return
	super._process(delta)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or mission == null or not _spent: return
	if mission.current_room != get_parent().get_parent(): return
	var player: Player = mission.player
	if not player.swimming(): return
	# Never materialize a solid box around a swimmer touching its underside.
	if Rect2(global_position-size*0.5,size).intersects(player.hitbox_rect()): return
	reset()
