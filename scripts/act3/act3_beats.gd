class_name Act3Beats
extends Node
## Act III's story, staged (SCRIPT.md's ACT THREE; docs/act3/ACT3_DESIGN.md).
## Same shape as Act1Beats/Act2Beats: a child of the world scene
## (ldtk/Act3World.tscn) that waits for SeaWorld to build its rooms, claims the
## Rumi triggers placed by tools/build_act3_world.py (defer_to_cutscene, so each
## plays this script's scene rather than its own one-liner), and listens for
## room changes and memories.
##
## Every scene plays once per save: SeaWorld.story["scene:<name>"]. A room
## opened cold (chapter browser, debug) counts the scenes before it as seen.
## A world with the `no_beats` meta (the route proof, the shot harness) runs
## none of it.

const HOOSHANG := Color(1.0, 1.0, 1.0, 1.0)
const RUMI_GOLD := LdtkRumiTrigger.RUMI_GOLD
const JAMSHID_WARM := Color(1.0, 1.0, 1.0, 1.0)
const DARKSHANG_SCENE := preload("res://scenes/characters/darkshang/DarkshangVisual.tscn")
const JAMSHID_SCENE := preload("res://scenes/characters/jamshid/Jamshid.tscn")
const PROMPT_SCENE := preload("res://scenes/ui/InputPrompt.tscn")
const DARK_SHADER := preload("res://assets/shaders/act3_dark.gdshader")
const CARPET_TEXTURE := preload("res://assets/props/magic_carpet/ride.png")
const MEMORY_SHEET := preload("res://assets/act3/sea/memories.png")

## Scenes in play order: name -> the room it belongs to. A cold open marks
## every scene whose room comes before the start room as already seen.
const SCENES := {
	"tide": "Act3_Level_0", "meeting": "Act3_Level_0", "gift": "Act3_Level_4",
	"currents": "Act3_Level_6", "lobby": "Act3_Level_9", "dark": "Act3_Level_12",
	"kept": "Act3_Level_13", "reef": "Act3_Level_14", "edge": "Act3_Level_18",
	"floor": "Act3_Level_21", "pond": "Act3_Level_22", "ascent": "Act3_Level_23",
	"office": "Act3_Level_24", "sea": "Act3_Level_25",
}

var _world: SeaWorld
var _fade: ColorRect
var _card: Label
var _busy := false
var _dark: ColorRect
var _dark_room: Node2D
var _shadow: Sprite2D
var _jamshid: Jamshid
var _rod_line: Line2D
var _still_phase := false
var _still_passed := 0
var _darkshang: DarkshangVisual
var _pond_waiting := false
var _ascent_watch := false
var _door_watch := false
var _sea_watch := false
var _dive_prompt: InputPrompt
var _ending_card := false


func _ready() -> void:
	_world = get_parent() as SeaWorld
	if _world == null:
		push_error("Act3Beats: put this inside the Act III world scene.")
		return
	for i in 20:
		if not _world.rooms.is_empty() and _world.player != null:
			break
		await get_tree().process_frame
	if _world.has_meta("no_beats"):
		set_process(false)
		return
	_build_fade()
	_build_shadow()
	if _world.story.get("cold_open", false):
		var start := LdtkWorld.index_in_name(str(_world.current_room.name))
		for scene: String in SCENES:
			if LdtkWorld.index_in_name(SCENES[scene]) < start:
				_world.story["scene:" + scene] = true
	for room in _world.rooms:
		for node in room.find_children("*", "Area2D", true, false):
			if node is LdtkRumiTrigger:
				var trigger := node as LdtkRumiTrigger
				trigger.snap_to_ground = room.name in ["Act3_Level_0"]
				trigger.defer_to_cutscene = true
				trigger.triggered.connect(_on_rumi.bind(str(room.name), trigger))
				if played(_scene_for_trigger(str(room.name))):
					trigger.set("_fired", true)
	for memory in get_tree().get_nodes_in_group("sea_memory"):
		(memory as SeaMemory).remembered.connect(_on_memory)
	_world.room_changed.connect(_on_room_changed)
	_world.player.died.connect(_on_player_died)
	_on_room_changed(_world.current_room)
	if str(_world.current_room.name) == "Act3_Level_0" and not played("tide"):
		_play_tide()


func played(scene: String) -> bool:
	return bool(_world.story.get("scene:" + scene, false))


func _mark(scene: String) -> void:
	_world.story["scene:" + scene] = true
	SaveGame.save_now()


func _scene_for_trigger(room_name: String) -> String:
	match room_name:
		"Act3_Level_0": return "meeting"
		"Act3_Level_4": return "gift"
		"Act3_Level_9": return "lobby"
		"Act3_Level_13": return "kept"
		"Act3_Level_14": return "reef"
		"Act3_Level_18": return "edge"
	return ""


# ------------------------------------------------------------------ rooms ---

func _on_room_changed(room: Node2D) -> void:
	var name := str(room.name)
	_set_dark(room if name == "Act3_Level_12" else null)
	_pond_waiting = false
	_ascent_watch = name == "Act3_Level_23"
	_door_watch = false
	_sea_watch = false
	match name:
		"Act3_Level_12":
			if not played("dark"):
				_play_dark.call_deferred(room)
		"Act3_Level_21":
			if not played("floor"):
				_play_floor.call_deferred(room)
		"Act3_Level_22":
			_place_jamshid(room)
			_pond_waiting = not played("pond")
		"Act3_Level_24":
			if not played("office"):
				_play_office.call_deferred(room)
			else:
				_door_watch = true
		"Act3_Level_25":
			_play_sea.call_deferred(room)


func _process(_delta: float) -> void:
	var player := _world.player
	if player == null:
		return
	if _dark != null and _dark.visible:
		(_dark.material as ShaderMaterial).set_shader_parameter("centre", player.global_position)
	# After the floor, the shadow he made peace with lies at his feet — on the
	# ground only: the bank, the office carpet, the beach at sunrise.
	if _shadow != null:
		_shadow.global_position = player.global_position + Vector2(0, Player.HALF_HEIGHT)
		_shadow.visible = played("floor") and player.is_on_floor() and not player.swimming()
	# The river, not the waterfall: the waterfall runs onto spikes, and a
	# conversation frozen in it would hand him back to them.
	if not played("currents") and not _busy and str(_world.current_room.name) == "Act3_Level_6" \
			and player.current_flow().x > 0.0:
		_play_currents()
	if _pond_waiting and not _busy and player.is_on_floor() and not player.swimming():
		_pond_waiting = false
		_play_pond(_world.current_room)
	if _ascent_watch and not _busy:
		var r := _world.room_rect(_world.current_room)
		if player.global_position.y < r.position.y + 48.0:
			_ascent_watch = false
			_play_ascent()
	if _door_watch and not _busy:
		var door := _mark_pos(_world.current_room, "Door")
		if player.global_position.x >= door.x:
			_door_watch = false
			_play_parking_lot()
	if _sea_watch and not _busy:
		var water := _mark_pos(_world.current_room, "Water")
		if player.global_position.x >= water.x and player.is_on_floor():
			_sea_watch = false
			_play_last_wave()
	if _dive_prompt != null and is_instance_valid(_dive_prompt):
		_dive_prompt.global_position = player.global_position + Vector2(0, -20 - _dive_prompt.lift)
		if player.diving():
			_dive_prompt.dismiss()
			_dive_prompt = null


func _on_rumi(player: Player, room_name: String, trigger: LdtkRumiTrigger) -> void:
	# Dropping into a room through its ceiling often lands him inside Rumi's
	# pillar while the portal slide still has him frozen. A conversation begun
	# then does not own that freeze, the slide's end unfreezes him mid-scene,
	# and the gift waited forever on a press while he swam away without the
	# Dive (rooms 4, 9 and 14). Let the slide finish first.
	while _world._transitioning or player._frozen:
		await get_tree().physics_frame
	match room_name:
		"Act3_Level_0": _play_meeting(trigger)
		"Act3_Level_4": _play_gift(trigger)
		"Act3_Level_9": _play_lobby(trigger)
		"Act3_Level_14": _play_reef(trigger)
		"Act3_Level_18": _play_edge(trigger)
		# The lift shaft's Rumi waits for the spray can (see _on_memory).


func _on_memory(memory: SeaMemory) -> void:
	if memory.kind == "can" and not played("kept"):
		for node in _world.current_room.find_children("*", "Area2D", true, false):
			if node is LdtkRumiTrigger:
				_play_kept(node as LdtkRumiTrigger)
				return


func _on_player_died() -> void:
	if _still_phase:
		_restart_stillness.call_deferred()


# ----------------------------------------------------------------- scenes ---

## ONE — THE TIDE. The wall's paint runs into a sea; he wakes old on the shore.
func _play_tide() -> void:
	_busy = true
	var player := _world.player
	player.freeze()
	_fade.color.a = 1.0
	var room := _world.current_room
	var wall := VerseWall.new()
	wall.position = _mark_local(room, "Wall") + Vector2(0, 8)
	room.get_node("Entities").add_child(wall)
	player.cutscene_rest(true, 1)
	await _show_card("ACT III", "THE SEA")
	await _fade_to(0.0, 1.6)
	await _hold(0.8)
	await wall.dissolve(3.4)
	wall.queue_free()
	await _hold(0.9)
	Dialogue.begin_conversation(self, player)
	player.cutscene_rest(true, 1)
	await _hooshang("...Old again.", "dazed")
	await _hooshang("I liked being seventeen. My knees liked it more.", "flat")
	Dialogue.end_conversation()
	player.unfreeze()
	_mark("tide")
	_busy = false


## ...and Rumi at the water's edge, the only colour anywhere.
func _play_meeting(trigger: LdtkRumiTrigger) -> void:
	if played("meeting"):
		return
	_busy = true
	var player := _world.player
	Dialogue.begin_conversation(self, player)
	await trigger.appear(18.0, 1.4)
	var side := trigger.portrait_side(player)
	await _rumi("You let go of his hand.", "serene", side)
	await _hooshang("Is that what that was.", "hesitant")
	await _rumi("You held it for fifty years, jaan. Your arm must be tired.", "warm_open", side)
	await _hooshang("All of me is tired.", "flat")
	await _hooshang("Where is this?", "confused")
	await _rumi("Beneath the office. Beneath the pond. This is the water all of it was floating on.", "serene", side)
	await _hooshang("It's very... black and white.", "skeptical")
	await _rumi("You have only seen the top of it.", "wistful", side)
	await _hooshang("You want me to go in there.", "wary")
	await _rumi("Down. All the way down.", "serene", side)
	await _hooshang("I'm an old man. I swim like a filing cabinet.", "deflecting")
	await _rumi("The sea does not ask a man his age. Only what he is carrying.", "warm_open", side)
	await _hooshang("And if he is carrying a great deal?", "unconvinced")
	await _rumi("Then he will sink quickly. That part is easy. Keep your eyes open.", "serene", side)
	if Dialogue.scene_skip_requested(self):
		trigger.vanish_immediately()
	else:
		await trigger.step_to(trigger.global_position.x + 60.0, 0.0, 1.6)
		await trigger.vanish()
	Dialogue.end_conversation()
	_mark("meeting")
	_busy = false


## TWO — THE GIFT. The Dive.
func _play_gift(trigger: LdtkRumiTrigger) -> void:
	if played("gift"):
		_world.player.has_swim_dash = true
		return
	_busy = true
	var player := _world.player
	Dialogue.begin_conversation(self, player, true)
	_swim_pose(player)
	await trigger.appear(0.0, 1.6)
	var side := trigger.portrait_side(player)
	await _rumi("You are swimming like a man filling out a form.", "serene", side)
	await _hooshang("I am swimming like a man who is about to drown.", "annoyed")
	await _rumi("You cannot drown here, jaan. This is the one place you never could.", "warm_open", side)
	await _rumi("Do not fight the sea. Lean the way you want to go, and let it carry you.", "serene", side)
	if not Dialogue.scene_skip_requested(self):
		await trigger.give_to(player)
	player.has_swim_dash = true
	player.refill_swim_dash()
	if Dialogue.scene_skip_requested(self):
		trigger.vanish_immediately()
	else:
		await trigger.vanish()
	Dialogue.end_conversation()
	_mark("gift")
	_show_dive_prompt()
	_busy = false


func _show_dive_prompt() -> void:
	_dive_prompt = PROMPT_SCENE.instantiate()
	_dive_prompt.touch_text = "SWIPE\nUNDER WATER"
	_world.add_child(_dive_prompt)
	_dive_prompt.show_at(_world.player.global_position + Vector2(0, -20))


## THREE — CURRENTS. The first time a current takes him.
func _play_currents() -> void:
	_busy = true
	_mark("currents")
	var player := _world.player
	Dialogue.begin_conversation(self, player, true)
	_swim_pose(player)
	await _hooshang("It's dragging me!", "shocked")
	await _rumi("It is going somewhere. You are only finding out where.", "serene", DialogueBox.Side.RIGHT)
	Dialogue.end_conversation()
	_busy = false


## FOUR — THE DROWNED OFFICE.
func _play_lobby(trigger: LdtkRumiTrigger) -> void:
	if played("lobby"):
		return
	_busy = true
	var player := _world.player
	Dialogue.begin_conversation(self, player, true)
	_swim_pose(player)
	await trigger.appear(0.0, 1.3)
	var side := trigger.portrait_side(player)
	await _hooshang("You have got to be joking.", "shocked")
	await _rumi("You brought it with you.", "serene", side)
	await _hooshang("I didn't bring it. I left it. They let me go.", "annoyed")
	await _rumi("You left the building, jaan. That is not the same thing.", "warm_open", side)
	if Dialogue.scene_skip_requested(self):
		trigger.vanish_immediately()
	else:
		await trigger.vanish()
	Dialogue.end_conversation()
	_mark("lobby")
	_busy = false


## The lowest floor, where the lights are out and the shadow drifts.
func _play_dark(room: Node2D) -> void:
	if _busy:
		return
	_busy = true
	_mark("dark")
	await _hold(0.6)
	var shade := _summon_shadow(room, _mark_pos(room, "Shadow"), 1.3)
	await _hold(1.2)
	var player := _world.player
	Dialogue.begin_conversation(self, player, true)
	_swim_pose(player)
	await _hooshang("It's back.", "wary")
	await _rumi("It never left. It lives where you live.", "sorrowful", DialogueBox.Side.RIGHT)
	await _rumi("Do not feed it. And do not run from it. Not yet.", "urgent", DialogueBox.Side.RIGHT)
	Dialogue.end_conversation()
	# It drifts off into the dark at the far end of the floor and is gone.
	var t := create_tween().set_parallel()
	t.tween_property(shade, "global_position", shade.global_position + Vector2(90, -10), 4.0)
	t.tween_property(shade, "modulate:a", 0.0, 4.0)
	_busy = false
	await t.finished
	shade.queue_free()


## The spray can, then Rumi at the bottom of the lift shaft.
func _play_kept(trigger: LdtkRumiTrigger) -> void:
	_busy = true
	var player := _world.player
	Dialogue.begin_conversation(self, player, true)
	_swim_pose(player)
	await trigger.appear(0.0, 1.2)
	var side := trigger.portrait_side(player)
	await _rumi("Every one of these you carried down here yourself.", "sorrowful", side)
	await _hooshang("I kept everything.", "vulnerable")
	await _rumi("Everything except the years.", "wistful", side)
	await _hooshang("...That's the part that's going to hurt, isn't it.", "sad")
	await _rumi("It already does. You have only been standing very still, so as not to notice.", "warm_open", side)
	if Dialogue.scene_skip_requested(self):
		trigger.vanish_immediately()
	else:
		await trigger.vanish()
	Dialogue.end_conversation()
	_mark("kept")
	_busy = false


## FIVE — THE REEF OF LANTERNS.
func _play_reef(trigger: LdtkRumiTrigger) -> void:
	if played("reef"):
		return
	_busy = true
	var player := _world.player
	Dialogue.begin_conversation(self, player, true)
	_swim_pose(player)
	await trigger.appear(0.0, 1.6)
	var side := trigger.portrait_side(player)
	await _hooshang("It's getting brighter.", "surprised")
	await _rumi("Yes.", "serene", side)
	await _hooshang("It's supposed to get darker the deeper you go. Everyone knows that.", "skeptical")
	await _rumi("Everyone knows a great many things about seas they have never been in.", "warm_open", side)
	await _rumi("Thoughts again — you know these. Step where they are not.", "serene", side)
	await _rumi("Though these, jaan, you may also land on.", "warm_open", side)
	if Dialogue.scene_skip_requested(self):
		trigger.vanish_immediately()
	else:
		await trigger.vanish()
	Dialogue.end_conversation()
	_mark("reef")
	_busy = false


## ...and at the edge of the trench, where Rumi's light becomes the sea's.
func _play_edge(trigger: LdtkRumiTrigger) -> void:
	if played("edge"):
		return
	_busy = true
	var player := _world.player
	Dialogue.begin_conversation(self, player, true)
	_swim_pose(player)
	await trigger.appear(0.0, 1.8)
	var side := trigger.portrait_side(player)
	await _rumi("From here, you go alone.", "serene", side)
	await _hooshang("You always say that right before the parts I'm going to hate.", "unconvinced")
	await _rumi("I always mean it.", "warm_open", side)
	if Dialogue.scene_skip_requested(self):
		trigger.vanish_immediately()
	else:
		await trigger.swell(4.0, 1.2)
		await trigger.vanish()
	Dialogue.end_conversation()
	_mark("edge")
	_busy = false


# ------------------------------------------------- SEVEN — THE FLOOR -------

func _play_floor(room: Node2D) -> void:
	if _busy:
		return
	_busy = true
	var player := _world.player
	# Let him come down to the sand first.
	for i in 240:
		if player.is_on_floor() or (player.swimming() and player.global_position.y > _mark_pos(room, "Stand").y - 20.0):
			break
		await get_tree().physics_frame
	Dialogue.begin_conversation(self, player, true)
	_swim_pose(player)
	await _hooshang("Rumi?", "wary")
	await _hold(1.4)
	await _hooshang("...Of course.", "sad")
	Dialogue.end_conversation()
	_darkshang = _summon_shadow(room, _mark_pos(room, "Shadow"), 3.0)
	await _hold(1.6)
	Dialogue.begin_conversation(self, player, true)
	_swim_pose(player)
	await _hooshang("Let it come.", "flat")
	await _hooshang("Let it stand.", "vulnerable")
	Dialogue.end_conversation()
	_start_stillness()


func _start_stillness() -> void:
	_still_phase = true
	_still_passed = 0
	var room := _world.current_room
	_show_caption("BE STILL", 3.0)
	for i in 10:
		if not _still_phase:
			return
		var angle := TAU * float(i) / 10.0 + 0.4
		var thought := StillThought.new()
		thought.target = _world.player
		thought.speed = 15.0 + float(i % 3) * 3.0
		room.add_child(thought)
		thought.global_position = _world.player.global_position + Vector2(cos(angle), sin(angle) * 0.7) * 150.0
		thought.resolved.connect(_on_still_resolved)
		await _hold(0.75)


func _on_still_resolved(_thought: StillThought, passed: bool) -> void:
	if not _still_phase or not passed:
		return
	_still_passed += 1
	if _still_passed >= 10:
		_still_phase = false
		_finish_floor()


func _restart_stillness() -> void:
	_still_phase = false
	for node in get_tree().get_nodes_in_group("still_thought"):
		node.queue_free()
	for child in _world.current_room.get_children():
		if child is StillThought:
			child.queue_free()
	await _hold(1.0)
	_show_caption("BE STILL", 2.0)
	await _hold(0.8)
	_start_stillness()


func _finish_floor() -> void:
	var player := _world.player
	player.freeze()
	_swim_pose(player)
	await _hold(0.8)
	# It comes close. Enormous. Then smaller. Then exactly his shape.
	var stop := player.global_position + Vector2(22.0, Player.HALF_HEIGHT)
	var t := create_tween().set_parallel()
	t.tween_property(_darkshang, "global_position", stop, 3.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(_darkshang, "scale", Vector2(-1, 1), 3.0).set_trans(Tween.TRANS_SINE)
	await t.finished
	await _hold(1.2)
	Dialogue.begin_conversation(self, player, true)
	_swim_pose(player)
	await _hooshang("You were only ever trying to keep me safe.", "vulnerable")
	await _hold(1.4)
	await _hooshang("I know. You did a terrible job.", "deflecting")
	Dialogue.end_conversation()
	player.freeze()
	await _hold(0.6)
	# He holds out his hand; the shadow takes it and folds down onto the sand.
	var fold := create_tween().set_parallel()
	fold.tween_property(_darkshang, "global_position", player.global_position + Vector2(0, Player.HALF_HEIGHT), 1.6)
	fold.tween_property(_darkshang, "scale", Vector2(1.6, 0.12), 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fold.tween_property(_darkshang, "modulate:a", 0.0, 1.6)
	await fold.finished
	_darkshang.queue_free()
	_mark("floor")
	Dialogue.begin_conversation(self, player, true)
	await _hooshang("Let it go.", "flat")
	Dialogue.end_conversation()
	player.unfreeze()
	_busy = false


# ---------------------------------------- EIGHT — THE POND AT THE BOTTOM ----

func _place_jamshid(room: Node2D) -> void:
	if _jamshid != null and is_instance_valid(_jamshid):
		return
	_jamshid = JAMSHID_SCENE.instantiate()
	_jamshid.initial_pose = "sit"
	room.get_node("Entities").add_child(_jamshid)
	_jamshid.global_position = _mark_pos(room, "Jamshid") + Vector2(0, 4)
	_jamshid.z_index = 2
	# His line runs from the rod's tip down into the pond.
	_rod_line = Line2D.new()
	_rod_line.width = 1.0
	_rod_line.default_color = Color(0.95, 0.92, 0.8, 0.8)
	_rod_line.z_index = 2
	room.get_node("Entities").add_child(_rod_line)
	var tip := _jamshid.global_position + Vector2(9, -10)
	var bob := _mark_pos(room, "Line")
	_rod_line.points = PackedVector2Array([tip, bob])


func _play_pond(room: Node2D) -> void:
	_busy = true
	var player := _world.player
	Dialogue.begin_conversation(self, player)
	player.cutscene_rest(false, -1)
	await _jamshid_say("Cousin joon.", "joyful")
	await _hooshang("You told me to come looking for you.", "vulnerable")
	await _jamshid_say("I said next time you're old.", "friendly")
	await _hooshang("I'm old.", "flat")
	await _jamshid_say("You took your time.", "friendly")
	await _hooshang("Are they biting?", "happy")
	await _jamshid_say("They would if old men stopped swimming through their house.", "joyful")
	Dialogue.end_conversation()
	# He sits down on the bank beside him. They fish.
	player.freeze()
	var seat := _mark_pos(room, "Hooshang")
	var walk := create_tween()
	walk.tween_property(player, "global_position:x", seat.x, absf(player.global_position.x - seat.x) / 40.0 + 0.1)
	player.visual.play("run")
	await walk.finished
	player.cutscene_rest(true, -1)
	await _hold(4.0)
	Dialogue.begin_conversation(self, player)
	player.cutscene_rest(true, -1)
	await _hooshang("I wasted it, Jamshid. I was so afraid of everything. I sat at one desk for fifteen years so that nothing could ever happen to me again.", "vulnerable")
	await _jamshid_say("Did it work?", "friendly")
	await _hooshang("No.", "sad")
	await _jamshid_say("Then you weren't wasting it. You were waiting.", "friendly")
	await _hooshang("For what?", "confused")
	await _jamshid_say("For you to come down.", "friendly")
	# The line tugs.
	if not Dialogue.scene_skip_requested(self):
		await _tug_line()
	await _jamshid_say("Finally!", "excited")
	var pearl := _reel_pearl(room)
	if not Dialogue.scene_skip_requested(self):
		await _hold(1.4)
	await _jamshid_say("Here. This one's yours.", "friendly")
	await _hooshang("What is it?", "surprised")
	await _jamshid_say("The rest of it.", "friendly")
	await _hooshang("The rest of what?", "confused")
	await _jamshid_say("Your time. Don't spend it all at a desk.", "determined")
	_school_bell()
	if not Dialogue.scene_skip_requested(self):
		await _hold(1.6)
	await _hooshang("That's yours.", "sad")
	await _jamshid_say("Not this time.", "friendly")
	await _jamshid_say("Go home, cousin joon.", "joyful")
	Dialogue.end_conversation()
	# The pearl goes to him, and goes IN: a little light he carries home.
	var give := create_tween().set_parallel()
	give.tween_property(pearl, "global_position", player.global_position + Vector2(0, -4), 1.0).set_trans(Tween.TRANS_SINE)
	give.tween_property(pearl, "modulate", Color(3, 3, 3, 0), 1.0)
	await give.finished
	pearl.queue_free()
	player.flash(Color(2.4, 2.2, 1.8))
	_mark("pond")
	player.unfreeze()
	_busy = false


func _tug_line() -> void:
	var bob := _rod_line.points[1]
	for i in 6:
		_rod_line.points = PackedVector2Array([_rod_line.points[0], bob + Vector2(0, 2 if i % 2 == 0 else 0)])
		await _hold(0.12)
	_rod_line.points = PackedVector2Array([_rod_line.points[0], bob])


func _reel_pearl(room: Node2D) -> Sprite2D:
	var pearl := Sprite2D.new()
	var tex := AtlasTexture.new()
	tex.atlas = MEMORY_SHEET
	tex.region = Rect2(80, 0, 16, 16)
	pearl.texture = tex
	pearl.z_index = 3
	room.get_node("Entities").add_child(pearl)
	pearl.global_position = _rod_line.points[1]
	var tip := _rod_line.points[0]
	var reel := create_tween().set_parallel()
	reel.tween_property(pearl, "global_position", tip + Vector2(-2, 6), 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reel.tween_method(func(p: Vector2) -> void:
		_rod_line.points = PackedVector2Array([tip, p]), _rod_line.points[1], tip + Vector2(-2, 6), 1.2)
	return pearl


func _school_bell() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = Act2Beats.school_bell_stream()
	p.volume_db = -14.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


# ---------------------------------------------------- NINE — THE SURFACE ----

func _play_ascent() -> void:
	_busy = true
	_mark("ascent")
	var player := _world.player
	_fade.color = Color(1, 1, 1, 0)
	var office := _room_named("Act3_Level_24")
	if office == null:
		_busy = false
		return
	_world.transition_with_sequence(office,
		func() -> void:
			await _fade_to(1.0, 2.4)
			await _hold(1.0)
			var black := create_tween()
			black.tween_property(_fade, "color", Color(0, 0, 0, 1), 1.2)
			await black.finished,
		func() -> void:
			player.cutscene_rest(true, 1))
	_busy = false


func _play_office(room: Node2D) -> void:
	_busy = true
	var player := _world.player
	player.freeze()
	player.global_position = _mark_pos(room, "Wake")
	player.cutscene_rest(true, 1)
	_fade.color = Color(0, 0, 0, 1)
	await _hold(1.0)
	# A fluorescent tube stutters on.
	for i in 3:
		_fade.color.a = 0.55
		await _hold(0.07)
		_fade.color.a = 1.0
		await _hold(0.18 + i * 0.1)
	await _fade_to(0.0, 1.2)
	Dialogue.begin_conversation(self, player)
	player.cutscene_rest(true, 1)
	await _hooshang("...Harder than I thought.", "dazed")
	Dialogue.end_conversation()
	# The photograph, among the spilled things. Into his pocket.
	var photo := Sprite2D.new()
	var tex := AtlasTexture.new()
	tex.atlas = MEMORY_SHEET
	tex.region = Rect2(16, 0, 16, 16)
	photo.texture = tex
	room.get_node("Entities").add_child(photo)
	photo.global_position = _mark_pos(room, "Box") + Vector2(0, 2)
	await _hold(1.0)
	var pick := create_tween().set_parallel()
	pick.tween_property(photo, "global_position", player.global_position, 0.8).set_trans(Tween.TRANS_SINE)
	pick.tween_property(photo, "scale", Vector2(0.3, 0.3), 0.8)
	await pick.finished
	photo.queue_free()
	player.unfreeze()
	_mark("office")
	_door_watch = true
	_busy = false


func _play_parking_lot() -> void:
	_busy = true
	var player := _world.player
	var sea := _room_named("Act3_Level_25")
	_world.transition_with_sequence(sea,
		func() -> void:
			await _fade_to(1.0, 1.0)
			Dialogue.begin_conversation(self, player)
			await _hooshang("Made it.", "flat")
			Dialogue.end_conversation()
			await _hold(1.2),
		func() -> void:
			pass)
	_busy = false


# ----------------------------------------------------- TEN — THE REAL SEA ---

func _play_sea(room: Node2D) -> void:
	var player := _world.player
	_fade.color = Color(0, 0, 0, 1)
	await _fade_to(0.0, 2.6)
	_sea_watch = true


func _play_last_wave() -> void:
	_busy = true
	var player := _world.player
	player.freeze()
	player.cutscene_rest(false, 1)
	await _hold(2.0)
	# Far out over the water, a carpet crosses the sun.
	var room := _world.current_room
	var carpet := Sprite2D.new()
	carpet.texture = CARPET_TEXTURE
	carpet.scale = Vector2(0.35, 0.35)
	carpet.modulate = Color(0.1, 0.06, 0.12, 0.85)
	carpet.z_index = -5
	room.add_child(carpet)
	var sun := room.global_position + Vector2(232, 70)
	carpet.global_position = sun + Vector2(-120, -6)
	var cross := create_tween()
	cross.tween_property(carpet, "global_position", sun + Vector2(130, -14), 7.0)
	await _hold(3.0)
	player.look(1)
	await cross.finished
	carpet.queue_free()
	await _hold(1.4)
	await _fade_to(1.0, 2.4)
	await _show_card("END OF ACT THREE", "")
	await _show_card("THE END", "")
	_mark("sea")
	Game.completed = true
	SaveGame.save_now()
	_finish_act()


func _finish_act() -> void:
	var results := preload("res://scenes/ui/ActResults.tscn").instantiate()
	results.stats = ActStats.finish()
	get_tree().root.add_child(results)
	await results.continued
	Dialogue.end_conversation()
	results.queue_free()
	SaveGame.save_now()
	var tree := get_tree()
	MainMenu.open.bind(tree).call_deferred()


# ---------------------------------------------------------------- helpers ---

func _summon_shadow(room: Node2D, at: Vector2, size: float) -> DarkshangVisual:
	var shade: DarkshangVisual = DARKSHANG_SCENE.instantiate()
	room.add_child(shade)
	shade.global_position = at
	shade.scale = Vector2(-size, size)
	shade.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(shade, "modulate:a", 1.0, 1.4)
	shade.set_motion(DarkshangVisual.STATE_IDLE, Vector2.ZERO)
	return shade


func _set_dark(room: Node2D) -> void:
	if room == null:
		if _dark != null:
			_dark.visible = false
		return
	if _dark == null or _dark_room != room:
		if _dark != null:
			_dark.queue_free()
		_dark = ColorRect.new()
		_dark.name = "Darkness"
		var r := _world.room_rect(room)
		_dark.size = r.size
		_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dark.z_as_relative = false
		_dark.z_index = 7  # over the water overlay (6), or the water lifts it
		var m := ShaderMaterial.new()
		m.shader = DARK_SHADER
		_dark.material = m
		room.add_child(_dark)
		_dark.global_position = r.position
		_dark_room = room
		# What can hurt him, and what he came for, still read in the dark.
		for node in room.find_children("*", "", true, false):
			if node is DarkThought or node is SeaMemory or node is Lemon:
				(node as CanvasItem).z_as_relative = false
				(node as CanvasItem).z_index = 8
	_dark.visible = true


func _build_shadow() -> void:
	# After the floor: an ordinary shadow at his feet, the kind a man casts
	# when he is standing in the light.
	_shadow = Sprite2D.new()
	var img := Image.create(12, 3, false, Image.FORMAT_RGBA8)
	for x in 12:
		for y in 3:
			var d := absf(x - 5.5) / 6.0 + absf(y - 1.0) / 2.0
			if d < 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.35 * (1.0 - d * 0.6)))
	_shadow.texture = ImageTexture.create_from_image(img)
	_shadow.z_index = -1
	_world.add_child(_shadow)
	_shadow.visible = played("floor")


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_card = Label.new()
	_card.anchor_right = 1.0
	_card.anchor_bottom = 1.0
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.add_theme_font_size_override("font_size", 40)
	_card.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	_card.modulate.a = 0.0
	layer.add_child(_card)


func _show_card(title: String, subtitle: String) -> void:
	_card.text = title + ("\n\n" + subtitle if subtitle != "" else "")
	var t := create_tween()
	t.tween_property(_card, "modulate:a", 1.0, 1.0)
	t.tween_interval(2.2)
	t.tween_property(_card, "modulate:a", 0.0, 1.0)
	await t.finished


func _show_caption(text: String, seconds: float) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.35, 0.22, 0.08))
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 0.72
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate.a = 0.0
	_fade.get_parent().add_child(label)
	var t := create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.6)
	t.tween_interval(seconds)
	t.tween_property(label, "modulate:a", 0.0, 0.8)
	t.finished.connect(label.queue_free)


func _fade_to(alpha: float, time: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", alpha, time)
	await t.finished


func _hold(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _swim_pose(player: Player) -> void:
	if player.swimming():
		player.visual.play("swim_idle")


func _hooshang(text: String, face: String) -> void:
	await Dialogue.say("Hooshang", text, HOOSHANG, Act1Beats.FACES.get(face), DialogueBox.Side.LEFT)


func _rumi(text: String, face: String, side: int) -> void:
	await Dialogue.say("Rumi", text, RUMI_GOLD, Act1Beats.RUMI_FACES.get(face), side)


func _jamshid_say(text: String, face: String) -> void:
	await Dialogue.say("Jamshid", text, JAMSHID_WARM, Jamshid.portrait(face), DialogueBox.Side.RIGHT)


func _room_named(room_name: String) -> Node2D:
	for room in _world.rooms:
		if str(room.name) == room_name:
			return room
	return null


func _mark_pos(room: Node2D, mark: String) -> Vector2:
	var node := room.get_node_or_null("Entities/" + mark) as Node2D
	return node.global_position if node != null else _world.room_rect(room).get_center()


func _mark_local(room: Node2D, mark: String) -> Vector2:
	return _mark_pos(room, mark) - room.get_node("Entities").global_position
