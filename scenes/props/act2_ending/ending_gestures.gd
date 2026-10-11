extends Node2D
## Cutscene-only visual double. The approved shared player library is untouched.
var player: Player
var can: Sprite2D
var holding_can := false
var spraying := false
var ink_target := Vector2.ZERO
var clock := 0.0

func pose(body: Player, clip: String, direction := 1) -> void:
	player = body
	player.visual.hide()
	$Actor.global_position = player.global_position
	$Actor.flip_h = direction < 0
	$Actor.play(clip)
	$Actor.show()

func release() -> void:
	if is_instance_valid(player): player.visual.show()
	$Actor.hide()
	holding_can = false
	spraying = false
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	if $Actor.visible and is_instance_valid(player):
		$Actor.global_position = player.global_position
	if holding_can and is_instance_valid(can) and is_instance_valid(player):
		can.global_position = player.global_position + Vector2(-8 if $Actor.flip_h else 8, -7)
		can.rotation = -0.15 if $Actor.flip_h else 0.15
	if spraying: queue_redraw()

func _draw() -> void:
	if not spraying or not is_instance_valid(can): return
	var from := to_local(can.global_position + Vector2(0,-4))
	var to := to_local(ink_target)
	for i in 12:
		var t := fposmod(clock * 2.0 + float(i) / 12.0, 1.0)
		var point := from.lerp(to,t) + Vector2(sin(i*7.0+clock*8.0)*t*3.0,0)
		draw_rect(Rect2(point.round(),Vector2.ONE),Color(0.19,0.35,0.33,(1.0-t)*0.6))
