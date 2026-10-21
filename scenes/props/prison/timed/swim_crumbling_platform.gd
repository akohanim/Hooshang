@tool
extends CrumblingPlatform
## Water-route crumble stones; restored only by respawn or room re-entry.
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
