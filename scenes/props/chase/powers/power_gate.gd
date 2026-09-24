extends RefCounted
## Resolve the physical actor once the active room owns him, never another room's
## boss. Used by both the trigger and eruption itself so direct calls are gated.
static func caster_for(source: Node) -> Darkshang:
	if not source.is_inside_tree(): return null
	var world: LdtkWorld
	var ancestor := source.get_parent()
	while ancestor != null:
		if ancestor is LdtkWorld:
			world = ancestor
			break
		ancestor = ancestor.get_parent()
	if world != null:
		if world.current_room == null or world.transition_target != null or not world.current_room.is_ancestor_of(source): return null
		var chamber := world.current_room.get_node_or_null("DarknessRoom")
		if chamber != null and is_instance_valid(chamber.get("chaser")):
			return chamber.get("chaser") as Darkshang
	for actor in source.get_tree().get_nodes_in_group("darkshang"):
		if world != null and world.current_room.is_ancestor_of(actor): return actor as Darkshang
		if world == null and actor.get_parent() == source.get_parent(): return actor as Darkshang
	return null
