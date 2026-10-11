extends Node
## Ordered prison state; movement/contact and imported-room routes are separate checks.
const Ledger=preload("res://scenes/props/prison/circuits/circuit_state.gd")
var failures:=0
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;push_error(label)
func _ready() -> void:
	var state=Ledger.new()
	var pads: Array[String]=["one","two","three","four","five"]
	check(state.register_circuit("library",pads,true),"register library melody")
	check(state.register_circuit("gym",pads,true),"register separate gym melody")
	state.touch("gym","one")
	state.touch("library","one");state.touch("library","three")
	check(not state.touched("library","one") and not state.solved("library"),"wrong order resets only unfinished melody")
	check(state.touched("gym","one"),"other melody unaffected")
	state.touch("library","one");state.touch("library","two");state.touch("library","two")
	check(not state.touched("library","one"),"repeated earlier pad cannot advance")
	state.touch("library","three");state.touch("library","one")
	check(state.touched("library","one"),"first note starts a fresh attempt")
	for pad in pads.slice(1):state.touch("library",pad)
	check(state.solved("library") and not state.solved("gym"),"all five ordered contacts required independently")
	state.reset_attempts()
	check(state.solved("library") and not state.touched("gym","one"),"death/exit preserves completion but resets partial melody")
	var restored=Ledger.new();restored.restore(state.save_completed())
	restored.register_circuit("library",pads,true);restored.register_circuit("gym",pads,true)
	check(restored.solved("library") and not restored.solved("gym"),"only solved melody persists")
	print("PRISON MUSIC ORDER: ",failures," failures")
	get_tree().quit(1 if failures else 0)
