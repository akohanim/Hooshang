extends RefCounted
## Act-local puzzle ledger. Only completed, registered circuits are serialized.
signal changed
signal wrong_note(id: String)
var _requirements: Dictionary = {}
var _partial: Dictionary = {}
var _completed: Dictionary = {}
var _restored: Array = []
var _orders: Dictionary = {}

func restore(raw: Variant) -> void:
	_restored = raw.duplicate() if raw is Array else []

func register_circuit(id: String, members: Array[String], ordered := false) -> bool:
	if id.is_empty() or members.is_empty() or _requirements.has(id): return false
	var unique: Dictionary = {}
	for member in members:
		if member.is_empty() or unique.has(member): return false
		unique[member] = true
	_requirements[id] = unique
	if ordered: _orders[id] = members.duplicate()
	if _restored.has(id): _completed[id] = true
	return true

func touch(id: String, member: String) -> bool:
	if not _requirements.has(id) or not _requirements[id].has(member) or solved(id): return false
	if not _partial.has(id): _partial[id] = {}
	if _orders.has(id):
		var next: int = _partial[id].size()
		if member != _orders[id][next]:
			_partial[id].clear()
			if member == _orders[id][0]: _partial[id][member] = true
			wrong_note.emit(id)
			changed.emit()
			return false
	if _partial[id].has(member): return false
	_partial[id][member] = true
	if _partial[id].size() == _requirements[id].size():
		_completed[id] = true
		_partial.erase(id)
	changed.emit()
	return true

func solved(id: String) -> bool:
	return _completed.has(id)

func touched(id: String, member: String) -> bool:
	return solved(id) or _partial.get(id, {}).has(member)

func reset_attempts() -> void:
	_partial.clear()
	changed.emit()

func save_completed() -> Array:
	return _completed.keys()
