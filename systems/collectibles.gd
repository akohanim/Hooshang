extends Node
## Running total of pomegranates (autoload "Collectibles").
##
## Lives here rather than on the player or a level because the count has to
## survive everything that throws those away: room changes inside an Act, death
## and respawn, and Act -> Act loads through Screen.load_scene(). An autoload is
## the project's home for cross-level state (STYLE_GUIDE §5).
##
## It also remembers WHICH fruit have been taken, not just how many. Rooms in an
## Act all stay loaded, so picking one up frees that node and it stays gone — but
## reloading the world (retrying from the debug picker, or coming back to an Act)
## would otherwise re-spawn fruit you already banked and let you farm the count.

signal changed(total: int)
signal collected(total: int)

## The banked total, carried across every level.
var total := 0

## collect_id -> true, for fruit already taken this session.
var _taken := {}

## Icon size and the HUD's authored design space. Everything on this layer is
## laid out at 1280x720 and scaled down by 4 — the trick DialogueBox uses to get
## type that isn't a magnified pixel grid (see systems/screen.gd).
const HUD_SCALE := 0.25
## Icon box in HUD px. A WHOLE multiple of the art it draws (20px dense frame x
## 2), the same rule deaths.gd follows: this layer is scaled by 0.25 onto the
## window, and a fractional upscale is what chewed the skull's eye sockets. It
## was 52 against a 16px frame — 3.25x — which is why the fruit up here always
## looked softer than the one in the room.
const ICON := 40.0

## The fruit's flight from where it was picked up to the counter.
const FLIGHT_TIME := 0.55
## How far the arc bows out of the straight line, as a share of the distance
## travelled, and the range that is clamped to. In HUD px, so 4x the game's.
const FLIGHT_BOW := 0.28
const FLIGHT_BOW_MIN := 40.0
const FLIGHT_BOW_MAX := 150.0
## What the fruit shrinks to by the time it lands.
const FLIGHT_END_SCALE := 0.5
## The authored HUD space, and how close to its edges the arc may pass.
const HUD_SIZE := Vector2(1280.0, 720.0)
const HUD_MARGIN := 24.0

var _hud: CanvasLayer
var _root: Control
var _icon: TextureRect
var _label: Label
var _punch: Tween

## What the counter is currently SHOWING, which trails `total` while a fruit is
## still in the air. `total` is banked the instant you touch the fruit — a
## number the rest of the game reads must never depend on an animation finishing
## — so the two are kept apart rather than deferring the real count.
var _shown := 0


func _ready() -> void:
	_build_hud()
	# Nothing to count with no world up (the title screen), so nothing to draw.
	Screen.scene_loaded.connect(func(scene: Node) -> void: _hud.visible = scene != null)


## Identifies the world a fruit belongs to, so two Acts can't collide on
## position alone.
func world_key() -> String:
	return Screen.current_path() if Screen.current != null else "?"


func is_taken(id: String) -> bool:
	return _taken.has(id)


## What the counter is displaying right now. Equals `total` except while a fruit
## is still flying to it. Public so a test can tell "the number went up" from
## "the number went up when the fruit landed".
func shown() -> int:
	return _shown


## Bank a fruit. `source` is the fruit itself: given one, it flies to the counter
## and the DISPLAYED number ticks over when it lands. The banked `total` goes up
## immediately either way.
func collect(id: String, amount := 1, source: CanvasItem = null) -> void:
	if _taken.has(id):
		return
	_taken[id] = true
	total += amount
	changed.emit(total)
	collected.emit(total)
	if source == null or not _launch(source, amount):
		_land(amount)


## Wipe the run — a fresh game, not a respawn. SaveGame.start_new() calls this.
func reset() -> void:
	total = 0
	_taken.clear()
	_shown = 0
	changed.emit(total)
	_refresh()


## This much of a save slot (see systems/save_game.gd). The taken SET goes with
## the total, not just the number: restoring "you have 7" without "and these are
## the seven" puts every banked fruit back in the world to be picked up again,
## which is the same farming hole `_taken` exists to close within a session.
func save_state() -> Dictionary:
	return {"total": total, "taken": _taken.keys()}


## Put a slot's fruit back. Must run BEFORE the world loads: each pomegranate
## asks is_taken() in its own _ready and shows itself if the answer is no.
func load_state(state: Dictionary) -> void:
	total = int(state.get("total", 0))
	_taken.clear()
	var taken: Variant = state.get("taken", [])
	if typeof(taken) == TYPE_ARRAY:
		for id in taken as Array:
			_taken[str(id)] = true
	# Straight to the number rather than through a flight: nothing was picked up,
	# a save was opened, and a fruit sailing in from the corner would be a lie
	# about where it came from.
	_shown = total
	changed.emit(total)
	_refresh()


## Counter in the corner. Built in code and parented here so it outlives every
## level, exactly like Game's fade layer. It sits OUTSIDE the game's
## sub-viewport, so it is drawn at the window's real resolution — see
## systems/screen.gd.
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "CollectibleHud"
	_hud.layer = 92  # over the world, under the dialogue box (95)
	_hud.scale = Vector2(HUD_SCALE, HUD_SCALE)  # authored at 1280x720
	add_child(_hud)

	# Grouped under one Control so the whole counter can be punched as a unit.
	_root = Control.new()
	_root.position = Vector2(40, 36)
	_root.size = Vector2(240, ICON)
	_root.pivot_offset = Vector2(0, ICON * 0.5)  # punch grows rightward
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_root)

	_icon = TextureRect.new()
	# The DENSE frame, not the world one. This layer draws at the window's own
	# resolution (see the 0.25 scale above), so it can show the finer art — the
	# same reason the dialogue box gets real type on a 180-line screen.
	_icon.texture = load("res://assets/props/pomegranate/dense/frame_000.png")
	_icon.size = Vector2(ICON, ICON)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_icon)

	_label = Label.new()
	_label.position = Vector2(60, 0)
	_label.size = Vector2(180, ICON)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.9))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_label)
	# Hidden until a world is up: the game boots to the title screen, and a
	# counter floating over the menu belongs to no run at all.
	_hud.visible = Screen.current != null
	_refresh()


func _refresh() -> void:
	if _label != null:
		_label.text = str(_shown)


# ------------------------------------------------------------- the flight ----

## Send a copy of the fruit arcing from where it was picked up to the counter.
## Returns false if it can't be staged, in which case the caller ticks the
## number over immediately — the count must never depend on the animation.
##
## The fruit and the counter live on DIFFERENT render surfaces: the fruit is in
## the 320x180 sub-viewport, the counter is on the window's own full-resolution
## layer (systems/screen.gd). So its start point has to be converted rather than
## copied — canvas position first, then up into this layer's 4x design space.
func _launch(source: CanvasItem, amount: int) -> bool:
	if _hud == null or not is_instance_valid(source) or not source.is_inside_tree():
		return false
	var start: Vector2 = source.get_global_transform_with_canvas().origin / HUD_SCALE
	var target := _root.position + Vector2(ICON, ICON) * 0.5

	var fruit := TextureRect.new()
	fruit.texture = _icon.texture
	fruit.size = Vector2(ICON, ICON)
	fruit.pivot_offset = Vector2(ICON, ICON) * 0.5  # scale about its middle
	fruit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fruit.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fruit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(fruit)

	var control := _bow(start, target)
	var offset := Vector2(ICON, ICON) * 0.5
	var t := create_tween().set_parallel()
	t.tween_method(func(k: float) -> void:
			fruit.position = _curve(start, control, target, k) - offset,
		0.0, 1.0, FLIGHT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fruit, "scale", Vector2.ONE * FLIGHT_END_SCALE, FLIGHT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# A callback rather than `await t.finished`: awaiting would make this a
	# coroutine, and its `bool` would come back to collect() as a coroutine
	# handle instead of a value — so every fruit would look like a failed launch
	# and tick the counter twice.
	t.chain().tween_callback(func() -> void:
		fruit.queue_free()
		_land(amount))
	return true


## The fruit reaching the counter is what makes the number go up.
func _land(amount: int) -> void:
	_shown = mini(_shown + amount, total)
	_refresh()
	_punch_counter()


## Control point for the flight: one bow out of the straight line, so the fruit
## sweeps rather than slides, and is moving fastest as it arrives.
##
## The bow is PERPENDICULAR to the path and always bulges downward — not simply
## "upward from the midpoint", which was the first version and was wrong for the
## one thing this animation does. The counter sits at the top of the screen, so
## an upward arc towards it leaves the screen: a fruit picked up near the ceiling
## flew clean off the top edge and only reappeared as it dropped into the corner.
func _bow(from: Vector2, to: Vector2) -> Vector2:
	var span := to - from
	var dist := span.length()
	if dist < 1.0:
		return from
	var dir := span / dist
	var perp := Vector2(-dir.y, dir.x)
	if perp.y < 0.0:
		perp = -perp  # always bulge away from the counter's corner
	var bow := clampf(dist * FLIGHT_BOW, FLIGHT_BOW_MIN, FLIGHT_BOW_MAX)
	var control := from.lerp(to, 0.5) + perp * bow
	# A pickup near an edge can still bow past it; keep the whole curve on screen.
	return control.clamp(Vector2(HUD_MARGIN, HUD_MARGIN), HUD_SIZE - Vector2(HUD_MARGIN, HUD_MARGIN))


## Quadratic Bezier through `control`.
func _curve(from: Vector2, control: Vector2, to: Vector2, k: float) -> Vector2:
	return from.lerp(control, k).lerp(control.lerp(to, k), k)


## A short knock as the fruit lands, so the number reads as having been struck
## rather than having quietly changed.
func _punch_counter() -> void:
	if _root == null:
		return
	if _punch and _punch.is_valid():
		_punch.kill()
	_root.scale = Vector2(1.3, 1.3)
	_punch = create_tween()
	_punch.tween_property(_root, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
