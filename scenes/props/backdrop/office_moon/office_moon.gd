class_name OfficeMoon
extends Node2D
## Shared lunar art placed inside an authored background window. The core/halo
## are unshaded so the compatibility renderer's per-item light cap cannot
## extinguish the moon; the PointLight separately illuminates nearby surfaces.

var _pool_active := false
var _selected := false
var _openings: Array = []

func _ready() -> void:
	set_notify_local_transform(true)
	_refresh_aperture()
	add_to_group("moon_candidates")
	set_moon_selected(false)

func moon_local_rect() -> Rect2:
	return $Core.transform * $Core.get_rect()

func set_moon_selected(selected: bool) -> void:
	_selected = selected
	$Core.visible = selected
	$Halo.visible = selected
	$Pool.enabled = selected and _pool_active
	_refresh_stars()

func configure(background: Texture2D, region: Rect2) -> void:
	position = region.get_center()
	$Core.texture = preload("res://assets/background/moon.png")
	$Core.scale = Vector2(16, 16) / $Core.texture.get_size()
	set_window_openings([region])

func set_window_openings(openings: Array) -> void:
	_openings = openings.duplicate()
	_refresh_aperture()

func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		_refresh_aperture()

func _refresh_aperture() -> void:
	if not has_node("Core") or $Core.texture == null:
		return
	WindowAperture.apply($Core, _openings, position)
	WindowAperture.apply($Halo, _openings, position)
	_refresh_stars()

func set_pool_enabled(active: bool) -> void:
	_pool_active = active
	$Pool.enabled = active and _selected

func _refresh_stars() -> void:
	if not is_inside_tree() or not has_node("Stars"):
		return
	# Draw in backdrop coordinates so moving the moon never moves the stars.
	$Stars.position = -position
	var excluded := Rect2()
	if _selected:
		excluded = moon_local_rect()
		excluded.position += position
	$Stars.configure(_openings, str(get_path()), excluded)
