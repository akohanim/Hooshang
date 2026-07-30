class_name NoteSequence
extends Node
## The musical-tile puzzle. Step the five NoteTiles in order 1..5 and Hooshang
## earns the glow. Step one out of order and the run resets — you start again
## from note 1.
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

var progress := 0          # how many correct steps so far (0..total)
var total := 0
var _solved := false
var _last_tile: NoteTile
var _last_time := -999.0
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
	# room takes the glow back and re-arms the puzzle, so it has to be earned
	# again. Both events are watched here rather than in the player, because
	# the puzzle owns its own reward's lifetime.
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null:
		_player.died.connect(_revoke)
	var world := _find_world()
	if world != null:
		world.room_changed.connect(func(_room: Node2D) -> void: _revoke())


func _on_tile_stepped(tile: NoteTile) -> void:
	if _solved:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if tile == _last_tile and now - _last_time < repeat_grace:
		return  # same pad, still standing on it — not a new step
	_last_tile = tile
	_last_time = now

	if tile.note_index == progress + 1:
		progress += 1
		progressed.emit(progress, total)
		if progress >= total and total > 0:
			_complete()
	else:
		# Wrong pad. Start over — but if they just stepped on note 1, that
		# counts as the first step of the new run rather than a dead stop.
		var was := progress
		progress = 1 if tile.note_index == 1 else 0
		broken.emit(was + 1, tile.note_index)
		if play_feedback and tile.note_index != 1:
			_play("res://assets/notes/wrong.wav")


func _complete() -> void:
	_solved = true
	completed.emit()
	if play_feedback:
		_play("res://assets/notes/success.wav")
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.grant_glow()


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
