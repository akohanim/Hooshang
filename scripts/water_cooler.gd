extends Area2D
## Glitched water cooler — dashing into or touching it refreshes the player's
## dash mid-air (mirrors Celeste's green dash-crystal mechanic).

signal dash_refreshed

var _used := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _used:
		return
	if body.has_method("refresh_dash"):
		body.refresh_dash()
		_used = true
		dash_refreshed.emit()
		_play_collect_effect()


func _play_collect_effect() -> void:
	# White burst → fade to invisible → free.
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.05)
	tween.tween_property(self, "modulate", Color(0.50, 1.00, 0.60, 0.0), 0.40)
	tween.tween_callback(queue_free)


## Called by the level to restore this cooler when the player respawns.
func reset() -> void:
	_used    = false
	modulate = Color.WHITE
	show()
