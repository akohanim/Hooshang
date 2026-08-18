extends Node
## RoomCollapse: everything hanging in the air comes down, and nothing else moves.
##
## Built here out of real prefabs on a hand-made floor rather than run against a
## level, because what this checks is the RULE — which things fall, where they
## stop, and what is left alone — and a level is a moving target for all three.
## Two of the four traps this covers can only be seen with real prefabs, though:
##
##   - a ConveyorBelt carries its own walkable floor on layer 1, so a naive
##     ground check finds the belt standing on ITSELF and no belt ever falls;
##   - GlassSpikes are a Hazard subclass, and `is_class` cannot see a GDScript
##     `class_name` at all, so a spike strip is invisible to a type test that
##     does not walk the script chain.
##
## Run:  godot --headless res://tests/collapse_test.tscn

const BELT := preload("res://scenes/props/zones/ConveyorBelt.tscn")
const SPIKES := preload("res://scenes/props/hazards/GlassSpikes.tscn")
const POM := preload("res://scenes/props/Lemon.tscn")

## Top of the floor everything lands on.
const FLOOR_Y := 200.0

var failures: Array[String] = []
var room: Node2D


func _ready() -> void:
	room = Node2D.new()
	add_child(room)
	_add_floor()

	# Three airborne props at three heights, plus one already on the floor and a
	# marker that has no business moving at all.
	var belt := _place(BELT.instantiate(), Vector2(40, 80))
	var spikes := _place(SPIKES.instantiate(), Vector2(90, 40))
	var pom := _place(POM.instantiate(), Vector2(140, 120))
	var grounded := _place(BELT.instantiate(), Vector2(190, FLOOR_Y - 8.0))
	var marker := _place(Marker2D.new(), Vector2(240, 60))
	await _frames(4)

	var resting := grounded.global_position.y
	var untouched := marker.global_position.y

	# --- what it decides, before anything moves -------------------------------
	var beat := RoomCollapse.duration(room)
	_check(beat > 0.0, "a room with things hanging in it has a collapse to play  [%.2fs]" % beat)
	_check(belt.has_meta("collapse_landing") and spikes.has_meta("collapse_landing")
			and pom.has_meta("collapse_landing"),
		"all three airborne props are picked up — belt, spikes and fruit alike")
	_check(not grounded.has_meta("collapse_landing"),
		"a prop already on the floor is left out of it")

	var dropped := RoomCollapse.drop(room, self)
	_check(dropped.size() == 3, "three things fall  [%d]" % dropped.size())
	_check(not dropped.has(marker), "and a marker is not one of them")

	# --- and what actually happens --------------------------------------------
	await _hold(beat + 0.35)
	_check(_lands_on_floor(belt), "the belt came to rest ON the floor  [%s]" % belt.global_position)
	_check(_lands_on_floor(spikes), "the spikes did too  [%s]" % spikes.global_position)
	_check(_lands_on_floor(pom), "and the fruit  [%s]" % pom.global_position)
	_check(is_equal_approx(grounded.global_position.y, resting),
		"the prop that was already down did not budge  [%.1f, was %.1f]"
			% [grounded.global_position.y, resting])
	_check(is_equal_approx(marker.global_position.y, untouched),
		"nor did the marker  [%.1f, was %.1f]" % [marker.global_position.y, untouched])
	# Scale is tweened for the landing squash and must come back. A prop left
	# squashed is a belt that is permanently the wrong shape, which nothing else
	# in the game would ever put right.
	_check(belt.scale.is_equal_approx(Vector2.ONE),
		"the landing squash sprang back  [%s]" % belt.scale)

	# The spikes hung highest and the fruit lowest, so the spikes were in the air
	# longest — the drop is a ripple, not everything snapping down together.
	_check(dropped[0] == belt and dropped[1] == spikes and dropped[2] == pom,
		"they are staggered left to right, so the room comes apart as a ripple")

	# --- a room with nothing hanging has no beat ------------------------------
	var settled := Node2D.new()
	add_child(settled)
	_check(is_zero_approx(RoomCollapse.duration(settled)),
		"an empty room asks for no hold at all  [%.2f]" % RoomCollapse.duration(settled))

	if failures.is_empty():
		print("COLLAPSE TEST: ALL PASS")
	else:
		print("COLLAPSE TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Within a couple of pixels of the floor, and not through it. Both halves
## matter: a prop that falls forever also "reaches" the floor on the way past.
func _lands_on_floor(prop: Node2D) -> bool:
	var bottom := RoomCollapse._bottom_of(prop)
	return absf(bottom - FLOOR_Y) <= 2.0


func _add_floor() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(400, 40)
	shape.shape = rect
	shape.position = Vector2(200, FLOOR_Y + 20.0)
	body.add_child(shape)
	room.add_child(body)


func _place(node: Node2D, at: Vector2) -> Node2D:
	node.position = at
	room.add_child(node)
	return node


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _hold(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
