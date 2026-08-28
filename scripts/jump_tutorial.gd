class_name JumpTutorial
extends Node
## Level_1: the room that teaches the jump key, right after he is on his feet.
##
## Simplest of the input lessons — jump needs no gift (he already has it, no
## Rumi hand-over the way DashTutorial gives the dash) and no catch (there is
## nothing here for him to fall into), so this is just: walk a couple of
## steps, read the prompt, press the key. The prompt FOLLOWS him rather than
## pinning him in place the way DashTutorial's does — nothing here pulls the
## floor out from under him, so there is nothing forcing him to stand still
## for it either.
##
## THE ICON MATCHES THE PAD. InputDevice tracks which kind of input last
## arrived; the prompt is built with whichever art matches at the moment it
## goes up, and swaps live if he picks up a controller (or sets it down)
## while it is still on screen — see _art_for_device()/_on_device_changed().

## The room this belongs to. Everything here is inert in every other room.
const ROOM := "Level_1"

@export_group("Where")
## How far past where he was standing when the room started he has to walk
## before the prompt appears — "a couple of steps forward". Not tied to any
## geometry the way DashTutorial's arm point is (there is no ledge here); a
## plain distance, meant to be retuned by eye.
@export var arm_distance := 24.0

@export_group("The prompt")
@export var key_art: Texture2D = preload("res://assets/ui/prompt_jump_key.png")
@export var pad_art: Texture2D = preload("res://assets/ui/prompt_jump_pad.png")
## How far above his head the bubble's tail sits when it first appears —
## matches InputPrompt.show_at's own anchor offset (see DashTutorial's call).
@export var lift_offset := Vector2(0.0, -6.0)

var _world: LdtkWorld
var _player: Player
var _armed := false
var _done := false
var _arm_at_x := 0.0
var _prompt: InputPrompt


func _ready() -> void:
	_world = get_parent() as LdtkWorld
	if _world == null:
		push_warning("JumpTutorial expects to be a child of LdtkWorld.")
		set_process(false)
		return
	_world.room_changed.connect(_on_room_changed)
	InputDevice.changed.connect(_on_device_changed)
	# After the player, so a frame that both moves him and arms the prompt
	# reads his POST-move position, not the one he started the frame at.
	process_priority = 100


func _on_room_changed(room: Node2D) -> void:
	if str(room.name) != ROOM:
		_teardown()
		return
	_player = _world.player
	# A death mid-lesson is not a room change — without this a retry starts
	# with the prompt already spent, which is a room that only teaches once.
	if not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)
	_arm(_player.global_position.x)


func _on_player_died() -> void:
	if _world == null or str(_world.current_room.name) != ROOM:
		return
	_teardown()
	# The signal fires the instant he dies, at wherever that happened to be —
	# not at the checkpoint he is about to stand up at. Arming from THAT
	# position would measure the walk from the wrong spot (mid-air over a
	# pit, past where the prompt used to trigger, anywhere). Wait for the
	# respawn LdtkWorld is already about to run — same span it uses at
	# ldtk_world.gd:506 — then read his position fresh, now that it is
	# actually the one he is walking from.
	await get_tree().create_timer(
		maxf(_world.respawn_delay, _player.death_time) + 0.25).timeout
	if _world == null or not is_instance_valid(_player) \
			or str(_world.current_room.name) != ROOM:
		return
	_arm(_player.global_position.x)


## Re-armed every entry (and every respawn in the room), same as
## DashTutorial: a retry teaches the same lesson rather than dropping him
## into a room whose prompt has already been spent.
func _arm(from_x: float) -> void:
	_arm_at_x = from_x + arm_distance
	_armed = true
	_done = false


func _physics_process(_delta: float) -> void:
	if _done or _player == null:
		return
	if _prompt == null:
		if not _armed or _player.global_position.x < _arm_at_x:
			return
		_show_prompt()
		return
	# Nothing pins him here, so the bubble has to keep up rather than being
	# placed once.
	_prompt.global_position = _player.global_position + lift_offset \
		+ Vector2(0.0, -_prompt.lift)
	if _player.state == Player.State.JUMP:
		_finish()


func _show_prompt() -> void:
	_armed = false
	_prompt = load("res://scenes/ui/InputPrompt.tscn").instantiate()
	_world.add_child(_prompt)
	_prompt.show_at(_player.global_position + lift_offset, _art_for_device())


func _art_for_device() -> Texture2D:
	return pad_art if InputDevice.is_controller() else key_art


func _on_device_changed(_device: InputDevice.Device) -> void:
	if _prompt != null:
		_prompt.set_texture(_art_for_device())


func _finish() -> void:
	_done = true
	if _prompt != null:
		_prompt.dismiss()
		_prompt = null


func _teardown() -> void:
	_armed = false
	if _prompt != null:
		_prompt.dismiss()
		_prompt = null
