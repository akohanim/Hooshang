extends RefCounted
## Per-rider memory of a moving surface's last horizontal speed.
## Standing after a stop keeps it briefly; departure consumes it exactly once.
var _samples := {}

func tick(delta: float) -> void:
	for id in _samples.keys():
		_samples[id].left -= delta
		if _samples[id].left <= 0.0:
			_samples.erase(id)

func remember(body: Node2D, speed: float, grace: float) -> void:
	if not is_zero_approx(speed):
		_samples[body.get_instance_id()] = {"speed": speed, "left": maxf(grace, 0.0)}

func take(body: Node2D, current_speed := 0.0) -> float:
	var id := body.get_instance_id()
	var speed: float = _samples.get(id, {}).get("speed", current_speed)
	_samples.erase(id)
	return speed

func forget(body: Node2D) -> void:
	_samples.erase(body.get_instance_id())

func clear() -> void:
	_samples.clear()
