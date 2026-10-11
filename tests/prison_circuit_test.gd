extends Node
## Component checks, not evidence of a played level route.
const Ledger = preload("res://scenes/props/prison/circuits/circuit_state.gd")
const Circuit = preload("res://scenes/props/prison/circuits/PrisonCircuit.tscn")
var failures := 0

class ProbePlayer extends CharacterBody2D:
	var input_locked := false
	var state := Player.State.IDLE
	func hitbox_rect() -> Rect2:
		return Rect2(global_position - Vector2(4, 6), Vector2(8, 12))

class Fixture extends Node2D:
	var circuits = Ledger.new()
	var props: Array = []
	var player: ProbePlayer
	var current_room: Node2D
	var _transitioning := false
	func circuit_reference(reference: Variant) -> Node2D:
		for prop in props:
			if prop.kind == "CircuitGate" and prop.entity_iid == str(reference): return prop
		return null

class SilentAudio extends Node:
	func play_cue(_cue: StringName) -> void: pass

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func frames(n: int = 3) -> void:
	for i in n: await get_tree().physics_frame

func _ready() -> void:
	SaveGame.unbind() # Fixture completion must never write a real slot.
	var ledger = Ledger.new()
	check(not ledger.register_circuit("empty", []), "empty circuit rejected")
	check(not ledger.register_circuit("duplicate", ["a", "a"]), "duplicate members rejected")
	check(ledger.register_circuit("library", ["a", "b", "c"]), "register valid circuit")
	check(not ledger.touch("library", "foreign"), "foreign node cannot advance circuit")
	check(ledger.touch("library", "b"), "nodes can be touched out of order")
	check(not ledger.touch("library", "b"), "repeated contact cannot substitute for another node")
	check(ledger.save_completed().is_empty(), "partial progress not saved")
	ledger.reset_attempts()
	check(not ledger.touched("library", "b"), "interrupted attempt resets")
	for member in ["c", "a", "b"]: ledger.touch("library", member)
	check(ledger.solved("library"), "all unique nodes complete circuit")
	ledger.reset_attempts()
	check(ledger.solved("library"), "completed circuit survives reset")
	var resumed = Ledger.new()
	resumed.restore(ledger.save_completed() + ["obsolete"])
	resumed.register_circuit("library", ["a", "b", "c"])
	check(resumed.save_completed() == ["library"], "only registered completions survive restore")
	var old_save = Ledger.new()
	old_save.restore(null)
	old_save.register_circuit("library", ["a", "b"])
	check(not old_save.solved("library"), "old save with no puzzle data starts unsolved")

	var world := Fixture.new()
	add_child(world)
	var audio := SilentAudio.new()
	audio.name = "Act2Audio"
	world.add_child(audio)
	world.current_room = Node2D.new()
	world.add_child(world.current_room)
	var entities := Node2D.new()
	world.current_room.add_child(entities)
	var gate = Circuit.instantiate()
	gate.kind = "CircuitGate"
	gate.entity_iid = "gate"
	gate.fields = {"CircuitId": "fixture"}
	gate.prop_size = Vector2(8, 48)
	gate.position = Vector2(80, 64)
	entities.add_child(gate)
	var nodes: Array = []
	for i in 2:
		var node = Circuit.instantiate()
		node.entity_iid = "node%d" % i
		node.fields = {"Gate": "gate"}
		node.position = Vector2(24 + i * 24, 64)
		entities.add_child(node)
		nodes.append(node)
	world.props = nodes + [gate] # Nodes deliberately bind before their gate.
	world.player = ProbePlayer.new()
	world.player.collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(8, 12)
	shape.shape = box
	world.player.add_child(shape)
	world.add_child(world.player)
	world.player.position = Vector2(8, 64)
	for prop in world.props: prop.bind(world)
	for prop in world.props: prop.refresh()
	await frames()
	check(not gate.barrier.disabled, "unsolved gate starts solid")
	world.player.input_locked = true
	world.player.position = nodes[0].position
	await frames()
	check(not world.circuits.touched("fixture", "node0"), "cutscene contact cannot advance circuit")
	world.player.input_locked = false
	await frames()
	check(nodes[0]._lit and not gate._open, "first contact lights one node without opening gate")
	world.player.position = Vector2(56, 64)
	var collision = world.player.move_and_collide(Vector2(80, 0))
	check(collision != null and world.player.position.x < 80, "physical gate blocks a crossing")
	world.circuits.reset_attempts()
	check(not nodes[0]._lit, "partial reset updates node appearance")
	world.player.position = nodes[1].position
	await frames()
	world.player.position = nodes[0].position
	await frames()
	check(gate._open and gate.barrier.disabled, "all contacts open visible and physical gate")
	world.circuits.reset_attempts()
	await frames()
	world.player.position = Vector2(56, 64)
	collision = world.player.move_and_collide(Vector2(80, 0))
	check(collision == null and world.player.position.x > 80, "completed gate stays traversable after reset")
	world.queue_free()
	await frames()
	print("PRISON CIRCUIT COMPONENTS: ", failures, " failures")
	get_tree().quit(1 if failures else 0)
