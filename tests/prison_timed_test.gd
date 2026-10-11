extends Node
## Deterministic timer and closure fixture, not a room route playtest.
const Ledger = preload("res://scenes/props/prison/timed/timed_state.gd")
const Puzzle = preload("res://scenes/props/prison/timed/TimedPuzzle.tscn")
var failures := 0
class Probe extends Node2D:
	func hitbox_rect() -> Rect2: return Rect2(global_position-Vector2(4.5,6),Vector2(9,12))
class Fixture extends Node2D:
	var timers = Ledger.new()
	var player: Probe
	var gate: Node2D
	func timed_reference(_reference: Variant) -> Node2D: return gate
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func frames(n: int=3) -> void:
	for i in n: await get_tree().physics_frame
func _ready() -> void:
	var ledger = Ledger.new()
	check(not ledger.register_puzzle("",8),"empty identity rejected")
	check(not ledger.register_puzzle("bad",-1),"negative duration rejected")
	check(ledger.register_puzzle("serving",8),"valid timer registered")
	check(not ledger.register_puzzle("serving",8),"duplicate identity rejected")
	check(not ledger.bank("serving"),"relay cannot complete an unstarted puzzle")
	ledger.start("serving")
	ledger.tick(3)
	check(is_equal_approx(ledger.remaining("serving"),5),"countdown follows elapsed simulation time")
	check(ledger.save_completed().is_empty(),"live countdown is never serialized")
	ledger.tick(6)
	check(not ledger.active("serving") and not ledger.bank("serving"),"expiry closes attempt and rejects late relay")
	ledger.start("serving",false)
	check(ledger.active("serving") and not ledger.bank("serving"),"return lever permits retreat without banking success")
	ledger.start("serving")
	check(ledger.bank("serving"),"main lever and relay bank success")
	ledger.reset_attempts()
	ledger.tick(30)
	check(ledger.solved("serving") and ledger.active("serving"),"banked success survives resets and elapsed time")
	var restored = Ledger.new()
	restored.restore(ledger.save_completed()+["obsolete"])
	restored.register_puzzle("serving",8)
	check(restored.save_completed()==["serving"],"only registered completion restored")
	var older = Ledger.new()
	older.restore(null)
	older.register_puzzle("serving",8)
	check(not older.active("serving"),"old save starts unsolved")
	var fixture := Fixture.new()
	add_child(fixture)
	fixture.player=Probe.new()
	fixture.add_child(fixture.player)
	fixture.player.position=Vector2(0,64)
	var gate = Puzzle.instantiate()
	gate.kind="TimedGate"
	gate.fields={"PuzzleId":"closure","Duration":1.0}
	gate.position=Vector2(80,64)
	gate.prop_size=Vector2(8,32)
	fixture.add_child(gate)
	gate.bind(fixture)
	fixture.gate=gate
	var linked = Puzzle.instantiate()
	linked.kind="TimedShutter"
	linked.fields={"Gate":"closure"}
	linked.position=Vector2(120,64)
	fixture.add_child(linked)
	linked.bind(fixture)
	var exit_seal = Puzzle.instantiate()
	exit_seal.kind="TimedShutter"
	exit_seal.fields={"Gate":"closure","RequireBank":true}
	exit_seal.position=Vector2(160,64)
	fixture.add_child(exit_seal)
	exit_seal.bind(fixture)
	await frames()
	check(not gate.barrier.disabled,"initial shutter solid")
	fixture.player.position=gate.position
	await frames()
	check(not gate.barrier.disabled,"overlap cannot open a never-activated gate")
	fixture.timers.start("closure")
	await frames()
	check(gate.barrier.disabled and linked.barrier.disabled,"one timer opens both physical shutters")
	check(not exit_seal.barrier.disabled,"completion-only exit stays closed during countdown")
	fixture.timers.tick(2)
	await frames()
	check(gate.barrier.disabled,"expired shutter cannot close through body")
	check(not linked.barrier.disabled and not exit_seal.barrier.disabled,"one occupied shutter cannot hold other shutters open")
	check(not fixture.timers.bank("closure"),"deferred collision does not extend relay deadline")
	fixture.player.position=Vector2(100,64)
	await frames()
	check(not gate.barrier.disabled,"shutter closes after body clears")
	fixture.timers.start("closure")
	fixture.timers.bank("closure")
	await frames()
	check(gate.barrier.disabled and linked.barrier.disabled and exit_seal.barrier.disabled,"banked completion opens linked shutters and exit seal")
	fixture.queue_free()
	await frames()
	print("PRISON TIMED COMPONENTS: ",failures," failures")
	get_tree().quit(1 if failures else 0)
