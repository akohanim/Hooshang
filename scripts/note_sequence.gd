class_name NoteSequence
extends Node
## The musical-tile puzzle. Step the five NoteTiles in order 1..5 and Hooshang
## earns the glow. Step one out of order and the run resets — you start again
## from note 1.
##
## A run is five DISTINCT pads, one step each, ascending. Stepping a pad that
## already counted this run breaks it, exactly like stepping the wrong one:
## "1, 2, 3, 3, 4, 5" is not the sequence, and letting a pad count twice was one
## of the two ways the glow could be earned without playing the tune. (The other
## was two pads counting off a single landing — see note_tile.gd.)
##
## Owns ONLY the ordering; each tile owns its own colour and pitch (see
## note_tile.gd). Finds its tiles through the "note_tile" group rather than a
## hardcoded list, so adding or moving tiles in a level needs no changes here.

signal progressed(step: int, total: int)
signal broken(expected: int, got: int)
signal completed

## Re-stepping the tile you're already standing on shouldn't count twice, and
## with a 1-cell pad the player can jitter across the edge. Ignore repeats of
## the same tile within this window.
@export var repeat_grace := 0.6
## Play a cue when the order is broken / when the run completes.
@export var play_feedback := true

const EXIT_SCENE = preload("res://scenes/props/music_exit/MusicExit.tscn")
## Seconds for the room to brighten after the melody unlocks the exit.
@export var light_release_time := 1.2
var _world: LdtkWorld
var _room: Node2D
var _room_tiles: Array[NoteTile] = []
var _exits: Dictionary = {}
## Door access is earned for this world run; glow/progress remain per life/visit.
## Keeping these separate prevents a return landing inside a reclosed shutter.
var _opened_rooms: Dictionary = {}
var _light_tween: Tween

var progress := 0          # how many correct steps so far (0..total)
var total := 0
var _solved := false
var _last_tile: NoteTile
var _last_time := -999.0
## Pads already counted in the current run, by instance id. Instances rather than
## note indices because two pads are allowed to share an index (see below), and
## then each of them is its own step.
var _counted := {}
var _audio: AudioStreamPlayer
var _player: Player


func _ready() -> void:
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	# Tiles register themselves in _ready too, so wait one frame for the whole
	# level (or every room of an LDtk world) to finish building.
	await get_tree().process_frame
	var tiles := get_tree().get_nodes_in_group("note_tile")
	# Length of the sequence is the HIGHEST index present, not the tile count.
	# Duplicates are legitimate — two tiles can both be note 3, and either one
	# advances the run — so counting tiles would demand a note 6 that does not
	# exist and the puzzle could never complete.
	total = 0
	for t in tiles:
		if t is NoteTile:
			total = maxi(total, t.note_index)
			t.stepped.connect(_on_tile_stepped)

	# The reward is scoped to THIS room and THIS life: dying or leaving the
	# room takes the glow back and re-arms the notes, so light has to be earned
	# again. Both events are watched here rather than in the player, because
	# the puzzle owns its own reward's lifetime.
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null:
		_player.died.connect(_revoke)
	_world = _find_world()
	if _world != null:
		_build_exits(tiles)
		_world.room_changed.connect(_room_changed)
		_room_changed(_world.current_room)


func _on_tile_stepped(tile: NoteTile) -> void:
	if _solved or (_world != null and tile not in _room_tiles):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if tile == _last_tile and now - _last_time < repeat_grace:
		return  # same pad, still standing on it — not a new step
	_last_tile = tile
	_last_time = now

	if tile.note_index == progress + 1 and not _counted.has(tile.get_instance_id()):
		progress += 1
		_counted[tile.get_instance_id()] = true
		progressed.emit(progress, total)
		if progress >= total and total > 0:
			_complete()
	else:
		# Wrong pad, or a pad that already had its turn. Start over — but if they
		# just stepped on note 1, that counts as the first step of the new run
		# rather than a dead stop.
		var was := progress
		_counted.clear()
		if tile.note_index == 1:
			progress = 1
			_counted[tile.get_instance_id()] = true
		else:
			progress = 0
		broken.emit(was + 1, tile.note_index)
		if play_feedback and tile.note_index != 1:
			_play("res://assets/notes/wrong.wav")

	_update_exit()


func _complete() -> void:
	_solved = true
	if _room != null: _opened_rooms[_room] = true
	completed.emit()
	if play_feedback:
		_play("res://assets/notes/success.wav")
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.grant_glow()
	_update_exit()
	if _world != null and _room != null:
		if _light_tween and _light_tween.is_valid():_light_tween.kill()
		_light_tween = create_tween()
		_light_tween.tween_property(_world.get_node("CanvasModulate"), "color", _world._ambient_color, light_release_time)


func _play(path: String) -> void:
	var s = load(path)
	if s != null:
		_audio.stream = s
		_audio.play()


## Wipe progress AND re-arm a solved puzzle. The earlier version bailed out
## early when `_solved` was set, which made the glow permanent once earned —
## the puzzle could never be run again.
func reset() -> void:
	progress = 0
	_solved = false
	_last_tile = null
	_last_time = -999.0
	_counted.clear()
	if _light_tween and _light_tween.is_valid():_light_tween.kill()
	_update_exit()
	if _world != null and _room != null and not _room_tiles.is_empty():
		_world.get_node("CanvasModulate").color = _world._ambient_color if _opened_rooms.has(_room) else _world.music_room_color


## Take the glow back and re-arm the tiles. Fires on death and on leaving the
## room; harmless if the puzzle was never solved.
func _revoke() -> void:
	reset()
	if _player != null:
		_player.revoke_glow()


## The LdtkWorld this puzzle belongs to, if any — normally this node's parent.
## Walked rather than assumed so the manager can be nested somewhere else.
func _find_world() -> LdtkWorld:
	var n := get_parent()
	while n != null:
		if n is LdtkWorld:
			return n
		n = n.get_parent()
	return null


func _build_exits(tiles: Array[Node]) -> void:
	# Include shelved rooms too, so they can be edited/tested without restoring
	# unrelated story rooms to the route. Ownership is always room-local.
	for tile in tiles:
		var room: Node = tile.get_parent()
		while room != null and not room is LDTKLevel:room = room.get_parent()
		if room == null or _exits.has(room):continue
		var exit: Node2D = _world._exit_in(room)
		if exit == null:continue
		var portal = EXIT_SCENE.instantiate()
		var bounds: Rect2 = _world.room_rect(room)
		var collider: CollisionShape2D
		for child in exit.get_children():
			if child is CollisionShape2D:collider=child
			elif child is CanvasItem:child.hide()
		if collider == null:
			portal.free();continue
		var top: float = collider.global_position.y - collider.shape.size.y / 2
		var x: float = bounds.end.x-32 if exit.global_position.x>bounds.get_center().x else bounds.position.x
		room.add_child(portal)
		portal.global_position=Vector2(x,top)
		portal.visible=false
		_exits[room]=portal
		room.set_meta("exit_locked",true)

func _room_changed(room: Node2D) -> void:
	if _room != null and _exits.has(_room):
		_exits[_room].visible=false
		_exits[_room].spill.enabled=false
	_room=room
	_room_tiles.clear()
	total=0
	for tile in get_tree().get_nodes_in_group("note_tile"):
		if room != null and room.is_ancestor_of(tile):
			_room_tiles.append(tile)
			total=maxi(total,tile.note_index)
	_revoke()
	if _exits.has(room):
		_exits[room].visible=true
		_exits[room].spill.enabled=true
		_exits[room].spill.energy=0

func _update_exit() -> void:
	if _room == null or not _exits.has(_room):return
	var opened := _solved or _opened_rooms.has(_room)
	_room.set_meta("exit_locked",not opened)
	_exits[_room].set_state(total if opened else progress,total,opened)
