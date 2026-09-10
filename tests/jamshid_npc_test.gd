extends Node
## JamshidNpc: the cousin standing in a room, greeting Hooshang when he comes
## near. Covers the reach (he does NOT call out from across the room), the
## once-per-load rule, the controls being taken and handed back, the ground
## probe, which side of the banner his face lands on, and the SCRIPT READING —
## the half that fails silently, by printing a stage direction on screen as
## though he said it.
##
## Mostly built by hand: what the bulk of this pins is the prop's own behaviour,
## and a room is only one placement of it. The last section is the other half —
## it loads the PACKED Act_2_Level_0 and checks he actually survived the LDtk
## round trip, which is the step CLAUDE.md records failing in silence (a newly
## handled entity stays raw data in ldtk/levels/*.scn and simply never appears,
## with no error anywhere). Where he stands is checked against the room's own
## tilemap rather than against a remembered pixel: solid under his feet, water
## to his left.
##
## Run:  godot --headless res://tests/jamshid_npc_test.tscn

const NPC_SCENE := preload("res://scenes/characters/jamshid/JamshidNpc.tscn")
const PLAYER := preload("res://scenes/characters/hooshang/Hooshang.tscn")

## The greeting as it is written into LDtk — the exact string
## tools/ldtk_add_jamshid.py places, so a change to one side fails here.
const GREETING := "(excited) Hooshang! Cousin joon!"

## Top edge of the slab everything stands on.
const FLOOR_Y := 100.0

var failures: Array[String] = []
var world: Node2D
var player: Player
var npc: JamshidNpc
## How many times the banner has been opened. `say()` closes and reopens it
## between LINES, so a one-line greeting is exactly one — which is what makes
## "he does not greet twice" checkable rather than merely "input is not locked",
## a state that would also be true of a beat that had already finished.
var _opens := 0


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	_build_floor(Vector2(0, FLOOR_Y), Vector2(600, 16))
	player = PLAYER.instantiate()
	world.add_child(player)
	Dialogue.dialogue_opened.connect(func() -> void: _opens += 1)
	await _run()


func _run() -> void:
	# ---- the script reading -------------------------------------------------
	# No staging needed: script_beats() is pure, which is the point of it being
	# public. A parenthetical is an instruction to the scene and must never
	# reach the screen as text (CLAUDE.md's dialogue rules).
	npc = NPC_SCENE.instantiate()
	npc.dialogue_line = GREETING
	# Off for this one: the reach checks below place him at Hooshang's own
	# resting height so the distance between them is purely horizontal, and a
	# probe that stood him on the floor would put his feet half a body below it.
	npc.snap_to_ground = false
	npc.position = Vector2(200, FLOOR_Y)
	world.add_child(npc)
	await _frames(2)

	var beats := npc.script_beats()
	_check(beats.size() == 1, "the greeting is one spoken line  [%d]" % beats.size())
	_check(beats[0]["text"] == "Hooshang! Cousin joon!",
		"...with the (excited) stage direction stripped  [%s]" % beats[0]["text"])
	_check(beats[0]["face"] == "excited",
		"...and read as a portrait state  [%s]" % beats[0]["face"])
	# The alias: "excited" has no drawing of its own and points at the joyful
	# one, so a script can ask for the acting rather than for the file.
	_check(Jamshid.portrait("excited") == Jamshid.portrait("joyful"),
		"'excited' resolves to the joyful painting")
	_check(Jamshid.portrait("excited").resource_path.get_file().get_basename()
			== "jamshid_joyful",
		"...and still NAMES that face, so DialogueBox can find its rig")

	# A line naming no state falls back to default_face rather than to "".
	npc.dialogue_line = "Cousin joon!"
	npc.default_face = "worried"
	_check(npc.script_beats()[0]["face"] == "worried",
		"a line that names no state wears default_face")
	npc.dialogue_line = GREETING
	npc.default_face = "friendly"

	# ---- the ground probe ---------------------------------------------------
	# His origin is his FEET (assets/characters/jamshid/README.md), so standing on the
	# floor means his own y IS the floor's top edge — no sprite padding to
	# measure off, unlike Rumi. Placed deliberately high, to be dropped.
	var high: JamshidNpc = NPC_SCENE.instantiate()
	high.position = Vector2(420, 20)
	world.add_child(high)
	await _frames(3)
	_check(is_equal_approx(high.global_position.y, FLOOR_Y),
		"he is stood on the floor below where he was placed  [y=%.1f]"
			% high.global_position.y)
	high.queue_free()

	# Let Hooshang settle onto the slab, then stand Jamshid at exactly that
	# height: the distance between them is then purely horizontal, so the
	# boundary checks below mean what they say.
	player.global_position = Vector2(60.0, FLOOR_Y - 40.0)
	await _frames(40)
	var rest_y := player.global_position.y
	_check(player.is_on_floor(), "Hooshang lands on the slab first")
	npc.trigger_radius = 50.0
	npc.position = Vector2(200.0, rest_y)

	# ---- the reach ----------------------------------------------------------
	player.global_position = Vector2(200.0 - 120.0, rest_y)
	player.velocity = Vector2.ZERO
	await _frames(6)
	_check(not npc._greeted, "he says nothing from 120px away")
	_check(not player.input_locked, "...and leaves Hooshang his controls")
	_check(_opens == 0, "...and never opens the banner  [%d]" % _opens)

	# Just outside. 51px, not 80 — a reach that is only roughly right would
	# pass a lazier margin.
	player.global_position = Vector2(200.0 - 51.0, rest_y)
	await _frames(4)
	_check(not npc._greeted, "still silent at 51px, one px outside the reach")

	# ---- and inside it ------------------------------------------------------
	player.global_position = Vector2(200.0 - 40.0, rest_y)
	await _frames(6)
	_check(npc._greeted, "he greets Hooshang at 40px")
	_check(player.input_locked, "...and takes his controls for the beat")
	_check(_opens == 1, "...opening the banner once  [%d]" % _opens)
	_check(Dialogue.get_node("NameLabel").text == "Jamshid",
		"...over his name  [%s]" % Dialogue.get_node("NameLabel").text)
	# He is standing to the RIGHT of Hooshang, so his face belongs on that end
	# of the banner — read off where he actually is, not off which way he faces.
	_check(npc.portrait_side(player) == DialogueBox.Side.RIGHT,
		"his face sits on the side he is standing on")

	# ---- pressing through it ------------------------------------------------
	# First press finishes the typewriter, second dismisses. A real InputEvent:
	# DialogueBox listens in _unhandled_input, which Input.action_press() does
	# not feed (the same note tests/intro_test.gd carries).
	for i in 60:
		if not player.input_locked:
			break
		_press_jump()
		await _frames(2)
		_press_jump()
		await _frames(2)
	_check(not player.input_locked, "the beat ends and hands his controls back")

	# ---- once per load ------------------------------------------------------
	# Walking away and coming back does not replay the reunion.
	var opens_after := _opens
	player.global_position = Vector2(200.0 - 200.0, rest_y)
	await _frames(6)
	player.global_position = Vector2(200.0 - 20.0, rest_y)
	await _frames(10)
	_check(_opens == opens_after,
		"walking back past him does not replay it  [%d opens, was %d]"
			% [_opens, opens_after])
	_check(not player.input_locked, "...and he keeps his controls")

	# ---- he survived the LDtk round trip -----------------------------------
	# The packed room, loaded on its own — no LdtkWorld needed, this only has to
	# prove the entity became a node with its fields on it. A `Jamshid` entity
	# the post-import hook did not handle would import as nothing at all.
	var room: Node2D = load("res://ldtk/levels/Act_2_Level_0.scn").instantiate()
	world.add_child(room)
	await _frames(2)
	var placed := _find_npc(room)
	_check(placed != null, "Act_2_Level_0 has a JamshidNpc in it")
	if placed != null:
		_check(placed.dialogue_line == GREETING,
			"...carrying the greeting  [%s]" % placed.dialogue_line)
		_check(is_equal_approx(placed.trigger_radius, 50.0),
			"...with a 50px reach  [%.0f]" % placed.trigger_radius)
		_check(placed.facing_left, "...facing left, back toward the water")
		# On the RIGHT side of the water: solid directly under his feet, and
		# water somewhere to his left along the row he is standing on. Read off
		# the room's own layers, so re-digging that pit fails here rather than
		# leaving him standing in mid-air.
		var solid := room.get_node_or_null("Collisions") as TileMapLayer
		var water := room.get_node_or_null("Water") as TileMapLayer
		_check(solid != null and water != null,
			"...in a room with both a Collisions and a Water layer")
		if solid != null and water != null:
			var cell := Vector2i(int(placed.position.x) / 8, int(placed.position.y) / 8)
			_check(solid.get_cell_source_id(cell) != -1,
				"...standing on solid ground  [cell %s]" % cell)
			_check(solid.get_cell_source_id(cell + Vector2i(0, -1)) == -1,
				"...with open air at his own height")
			var wet := false
			for dx in range(1, cell.x + 1):
				if water.get_cell_source_id(cell - Vector2i(dx, 0)) != -1:
					wet = true
					break
			_check(wet, "...and the water is to his LEFT — he is on its right bank")
	room.queue_free()

	if failures.is_empty():
		print("JAMSHID NPC TEST: ALL PASS")
	else:
		print("JAMSHID NPC TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## The one JamshidNpc anywhere under `node`. Searched rather than pathed: the
## importer decides what the Entities layer's children are called, and a path
## typed here would be a second place that has to agree with it.
func _find_npc(node: Node) -> JamshidNpc:
	if node is JamshidNpc:
		return node
	for child in node.get_children():
		var found := _find_npc(child)
		if found != null:
			return found
	return null


## A slab of world (physics layer 1) for the probe to find and the player to
## stand on. `at` is its top-left corner.
func _build_floor(at: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at + size * 0.5
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	world.add_child(body)


func _press_jump() -> void:
	var ev := InputEventAction.new()
	ev.action = "jump"
	ev.pressed = true
	Input.parse_input_event(ev)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
