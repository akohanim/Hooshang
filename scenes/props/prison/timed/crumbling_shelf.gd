@tool
extends CrumblingPlatform
## Timed-route crumble stones. Respawn/room re-entry owns restoration; using
## the linked lever again must not bring back platforms during the same visit.
@export var kind := "CrumblingShelf"
@export var fields: Dictionary = {}
var mission: Node

func bind(world: Node) -> void:
	mission = world

func refresh() -> void:
	pass
