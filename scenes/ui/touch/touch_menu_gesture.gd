extends RefCounted
## One owned finger; activate on release, cancel on drag/cancel, optionally scroll.
var finger := -1
var origin := Vector2.ZERO
var previous := Vector2.ZERO
var dragged := false

func read(event: InputEvent, scrolling := false) -> Dictionary:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and finger < 0:
			finger = event.index
			origin = event.position
			previous = origin
			dragged = false
		elif event.index == finger and (not event.pressed or event.canceled):
			finger = -1
			if not event.canceled and not dragged and origin.distance_to(event.position) < 8.0:
				return {"tap": event.position}
	elif event is InputEventScreenDrag and event.index == finger:
		if origin.distance_to(event.position) > 8.0:
			dragged = true
		if scrolling and absf(event.position.y - previous.y) >= 16.0:
			var step := -1 if event.position.y > previous.y else 1
			previous = event.position
			return {"scroll": step}
	return {}

func reset() -> void:
	finger = -1
	dragged = false
