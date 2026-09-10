extends Node

func _ready() -> void:
	var scene := preload("res://scenes/props/backdrop/WindowStars.tscn")
	var stars = scene.instantiate()
	add_child(stars)
	var panes := [Rect2(0, 0, 30, 50), Rect2(40, 0, 30, 50)]
	stars.configure(panes, "window_a")
	var first: Array = stars.points.duplicate()
	assert(first.size() >= 10)
	for point in first:
		assert(panes[0].grow(-2).has_point(point) or panes[1].grow(-2).has_point(point))
		assert(point == point.floor())
	stars.configure(panes, "window_b")
	assert(stars.points != first, "Different windows need different constellations")
	stars.configure(panes, "window_a")
	assert(stars.points == first, "Revisiting must preserve the stars")
	stars.configure(panes, "window_a", Rect2(4, 4, 16, 16))
	for point in stars.points:
		assert(panes[1].has_point(point), "Moon pane must stay clear")
	var window = preload("res://scenes/props/backdrop/MoonWindow.tscn").instantiate()
	add_child(window)
	window.set_moon_selected(false)
	assert(window.get_node("Stars").visible)
	assert(not window.get_node("Stars").points.is_empty())
	window.set_moon_selected(true)
	assert(not window.get_node("Stars").visible)
	var office = preload("res://scenes/props/backdrop/office_moon/OfficeMoon.tscn").instantiate()
	add_child(office)
	office.configure(null, panes[0])
	office.set_window_openings(panes)
	office.set_moon_selected(true)
	assert(not office.get_node("Stars").points.is_empty())
	for point in office.get_node("Stars").points:
		assert(panes[1].has_point(point))
	office.set_moon_selected(false)
	assert(office.get_node("Stars").points.size() > stars.points.size())
	print("PASS: stars vary, persist, stay in glass, and avoid moon panes")
	get_tree().quit()
