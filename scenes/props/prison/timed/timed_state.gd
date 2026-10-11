extends RefCounted
## Only relay-banked success persists. Live countdowns are local attempts.
signal changed
signal attempt_started(id: String)
signal lever_used(id: String)
var _durations: Dictionary = {}
var _remaining: Dictionary = {}
var _completed: Dictionary = {}
var _bankable: Dictionary = {}
var _restored: Array = []

func restore(raw: Variant) -> void:
	_restored = raw.duplicate() if raw is Array else []

func register_puzzle(id: String, duration: float) -> bool:
	if id.is_empty() or _durations.has(id) or not is_finite(duration) or duration<=0: return false
	_durations[id] = duration
	if _restored.has(id): _completed[id] = true
	return true

func start(id: String, can_bank := true) -> bool:
	if not _durations.has(id): return false
	# A solved room stays solved, but its lever still restores temporary footing.
	lever_used.emit(id)
	if solved(id): return false
	_remaining[id] = _durations[id]
	_bankable[id] = can_bank
	attempt_started.emit(id)
	changed.emit()
	return true

func bank(id: String) -> bool:
	if solved(id) or not active(id) or not _bankable.get(id,false): return false
	_completed[id] = true
	_remaining.erase(id)
	changed.emit()
	return true

## Pressure plates refresh the release grace while occupied, without repeatedly
## firing activation/audio or resetting linked props every physics frame.
func hold(id: String) -> bool:
	if not _durations.has(id) or solved(id): return false
	if not _remaining.has(id) or not _bankable.get(id,false): return start(id)
	_remaining[id] = _durations[id]
	changed.emit()
	return false

func tick(delta: float) -> void:
	if delta<=0 or not is_finite(delta): return
	if _remaining.is_empty(): return
	for id in _remaining.keys():
		_remaining[id] = maxf(0,float(_remaining[id])-delta)
		if _remaining[id]<=0: _remaining.erase(id)
	changed.emit()

func solved(id: String) -> bool:
	return _completed.has(id)

func active(id: String) -> bool:
	return solved(id) or remaining(id)>0

func remaining(id: String) -> float:
	return float(_remaining.get(id,0.0))

func fraction(id: String) -> float:
	return 1.0 if solved(id) else remaining(id)/float(_durations.get(id,1.0))

func reset_attempts() -> void:
	_remaining.clear()
	_bankable.clear()
	changed.emit()

func save_completed() -> Array:
	return _completed.keys()
