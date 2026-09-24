extends Node
## Scene-owned ambience: fades in for the encounter and out before control returns.
## Night insect level below the fire crackles.
@export var crickets_db := -24.0
## Dawn birds remain soft under the final conversation.
@export var birds_db := -22.0

var _mix: Tween

func blend(night: float, dawn: float, duration: float) -> void:
	if _mix != null and _mix.is_valid():
		_mix.kill()
	_mix = create_tween().set_parallel()
	var players := [$Crickets, $Birds]
	var gains := [db_to_linear(crickets_db) * night, db_to_linear(birds_db) * dawn]
	for i in players.size():
		if not players[i].playing:
			players[i].play()
		_mix.tween_property(players[i], "volume_linear", gains[i], duration)

func finish() -> void:
	if _mix != null and _mix.is_valid():
		_mix.kill()
	_mix = create_tween().set_parallel()
	for player in [$Crickets, $Birds]:
		_mix.tween_property(player, "volume_linear", 0.0, 0.6)
	await _mix.finished
	queue_free()
