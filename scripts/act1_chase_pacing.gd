extends Node
## One real Darkshang follows the escape route, with the room directing attacks.
## His own chase, checkpoint reset and ingestion remain authoritative.
## Size relative to the original 0.6-scale reveal in Level_14; 2.5 is 250%.
@export var first_encounter_size_multiplier := 2.5
## First encounter's enlarged visible body, excluding the trailing smoke.
@export var first_encounter_catch_size := Vector2(40, 64)
## Lift absorption from his feet to the torso.
@export var first_encounter_catch_offset := Vector2(0, -28)
var _ordinary_catch_size := Vector2.ZERO
var _ordinary_catch_offset := Vector2.ZERO
var world:LdtkWorld
var shadow:Darkshang
var chamber:Node2D
func _ready()->void:
	world=get_parent() as LdtkWorld
	await get_tree().process_frame
	shadow=get_tree().get_first_node_in_group("darkshang") as Darkshang
	_ordinary_catch_size = shadow.catch_size
	_ordinary_catch_offset = shadow.catch_offset
	# Chase pacing is runtime data. Read these fields from the source recipes so
	# changing pursuit does not depend on rebuilding LDtk's cached room scenes.
	var chase_settings := {}
	var recipes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/act1_expansion.json"))
	for recipe: Dictionary in recipes:
		chase_settings[recipe.name] = recipe.get("encounter", {})
	for room in world.rooms:
		var encounter:=room.get_node_or_null("DarknessRoom")
		if encounter!=null:
			var settings: Dictionary = chase_settings.get(str(room.name), {})
			for key in ["continuous_chase", "follow_delay", "surge_speed", "surge_interval", "cloud_form"]:
				if settings.has(key): encounter.e[key] = settings[key]
			encounter.bind(world)
	world.room_changed.connect(_arrive)
	world.transition_started.connect(_transition)
	world.player.died.connect(_death)
	_arrive(world.current_room)
	var trapdoor := preload("res://scenes/props/chase/trapdoor/EncounterTrapdoor.tscn").instantiate()
	trapdoor.name = "EncounterTrapdoor"
	world.add_child(trapdoor)
	trapdoor.bind(world, shadow)
func _transition(_room:Node2D)->void:
	if chamber!=null:chamber.leave()
	if shadow!=null and world.current_room.name!="Level_14":shadow.stand_by()
func _arrive(room:Node2D)->void:
	shadow.absorb_on_reveal = room.name == "Level_14"
	shadow.catch_size = first_encounter_catch_size if shadow.absorb_on_reveal else _ordinary_catch_size
	shadow.catch_offset = first_encounter_catch_offset if shadow.absorb_on_reveal else _ordinary_catch_offset
	if chamber!=null:chamber.leave()
	chamber=room.get_node_or_null("DarknessRoom")
	shadow.cloud_reveal_on_entry = room.name == "Level_18"
	if shadow._visual != null:
		shadow._visual.cloud_transition_left = 0.0
		shadow._visual.cloud_form = shadow.cloud_reveal_on_entry or _has_charge(room) or (chamber != null and bool(chamber.e.get("cloud_form", false)))
	if chamber!=null:
		shadow.stand_by()
		chamber.enter()
		if chamber.e.get("continuous_chase",false):
			chamber.chaser=shadow
			shadow.follow_delay=float(chamber.e.follow_delay)
			shadow.surge_speed=float(chamber.e.surge_speed)
			shadow.surge_warning=.7
			shadow.respawn_gap=128
			shadow.entry_hold_distance=24
			shadow.entry_room_bounds=world.room_rect(room)
			shadow.route_direction=Vector2(float(chamber.recipe.direction),0)
			shadow.modulate=Color.WHITE
			if shadow._visual!=null:shadow._visual.scale=Vector2(.9,.9)
			shadow.start_chase()
			shadow.reset_to_checkpoint(world.player.global_position)
	elif room.name=="Level_14":
		shadow.entry_room_bounds=Rect2()
		shadow.entry_hold_distance=16
		if shadow._visual!=null:shadow._visual.scale=Vector2.ONE * .6 * first_encounter_size_multiplier
	elif room.name=="Level_26":
		# Follow him home. Act1Beats stops and dissolves the same actor only
		# when Hooshang reaches the cubicle's ending line, not at the door.
		shadow.stand_by()
		shadow.follow_delay=3.2
		shadow.respawn_gap=128
		shadow.entry_hold_distance=24
		shadow.entry_room_bounds=world.room_rect(room)
		shadow.route_direction=Vector2.LEFT
		shadow.modulate=Color.WHITE
		if shadow._visual!=null:shadow._visual.scale=Vector2(.9,.9)
		shadow.start_chase()
		shadow.reset_to_checkpoint(world.player.global_position)
func _death()->void:
	if chamber!=null:chamber.reset_after_death()

## Charge art is shared by every authored charge, not a Level_19 exception.
## Read the placed triggers so newly authored charge rooms inherit it too.
func _has_charge(room: Node2D) -> bool:
	for trigger in get_tree().get_nodes_in_group("darkshang_power_trigger"):
		if room.is_ancestor_of(trigger) and trigger.power == 0:
			return true
	return false
