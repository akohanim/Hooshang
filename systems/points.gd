extends Node
## The run's score (autoload "Points"), shown top-left under the fruit counter.
##
## Same reasoning as Collectibles and Deaths: the number has to survive
## everything that throws the player away — room changes inside an Act, death and
## respawn, and Act -> Act loads through Screen.load_scene() — so it lives in an
## autoload, this project's home for cross-level state (STYLE_GUIDE §5).
##
## WHAT IT IS NOT: the fruit count. Collectibles counts LEMONS, one per lemon,
## and that is what a save is really about — which fruit are still out there.
## This is a score on top of it, and the two are deliberately separate numbers:
## making the fruit count worth 1000 each would mean a player who reads "7" in
## one corner and "7000" in the other is looking at the same fact twice.
##
## Awards come in through `award()`, which is also what puts the "+N" on screen.
## Anything that pays out calls it; nothing has to know the tag exists.

signal changed(total: int)

## Points so far this run.
var total := 0

## What a lemon is worth. The number on the tag in the reference art, and the
## only award in the game so far.
const LEMON := 1000

## The counter rolls rather than jumps — a score that snaps is a number, a score
## that runs up is a reward. This is how long it takes to catch up, whatever the
## size of the award, so a big one runs faster rather than longer.
const ROLL_TIME := 0.45

## Icon-less, unlike the other two counters: a score does not need a picture to
## say what it is, and there is no art for one that would not just be noise
## under the lemon.
const ROW := Vector2(40.0, 88.0)
const ROW_SIZE := Vector2(240.0, 40.0)

# ------------------------------------------------------------ the "+N" tag ---
#
# Composed from a sheet at runtime rather than being one drawn picture. It WAS
# one picture of "+1000", which is right up until something awards a different
# number and the tag says 1000 anyway — a lie the code cannot see it is telling.
#
# It lives on this HUD layer and not in the world, which is the whole reason it
# is visible: the world is rasterised under a CanvasModulate of 0.05, and a
# painted tag there arrives at 5% of what was drawn.
const DIGITS := preload("res://assets/ui/points_digits.png")
const SPARK := preload("res://assets/ui/points_spark.png")
## Cell size on the sheet and the order of the glyphs in it — see
## tools/gen_points_popup.py, which will not reorder them.
const GLYPH_CELL := Vector2(17.0, 19.0)
const GLYPH_ORDER := "+0123456789"
## How far apart the glyph BODIES sit: nine wide plus a pixel. Less than the cell,
## so consecutive glows overlap the way they would in a single drawing.
const GLYPH_ADVANCE := 10.0
## Whole-number scale, or the pixels stop being square.
const POPUP_SCALE := 1.0
## How far it drifts up while it is on screen, in this layer's px.
const POPUP_RISE := 40.0
## About a second. The fade takes the last third, so it is fully legible for
## most of its life rather than dying from the moment it appears.
const POPUP_TIME := 1.0
const POPUP_FADE := 0.34
## Where the sparks sit, as fractions of the tag's own box.
const SPARKS := [Vector2(0.08, 0.12), Vector2(0.38, -0.05),
	Vector2(0.66, 0.9), Vector2(0.94, 0.28)]

var _hud: CanvasLayer
var _root: Control
var _label: Label
var _punch: Tween
var _roll: Tween
## What the counter is DISPLAYING, which trails `total` while it rolls. Public
## through shown() so a test can tell the banked number from the drawn one.
var _shown := 0


func _ready() -> void:
	_build_hud()
	# Nothing to score with no world up (the title screen), so nothing to draw.
	Screen.scene_loaded.connect(func(scene: Node) -> void: _hud.visible = scene != null)


## Pay out. `source` is whatever earned it — the tag pops over that, so a fruit
## passes itself. Without one there is no tag: a scripted award has no position
## on screen, and a "+1000" in the corner of a room it did not come from is
## worse than none at all.
func award(amount: int, source: CanvasItem = null) -> void:
	if amount == 0:
		return
	total += amount
	changed.emit(total)
	_roll_to(total)
	_punch_counter()
	if amount > 0:
		_popup(amount, source)


## What the counter is showing, which lags `total` while the roll runs. Nothing
## in the game may read this — it is the display, and the score is `total`.
func shown() -> int:
	return _shown


## Wipe the run — a fresh game, not a respawn. SaveGame.start_new() calls this
## alongside Collectibles.reset() and Deaths.reset().
func reset() -> void:
	total = 0
	_set_shown(0)


## This much of a save slot (see systems/save_game.gd).
func save_state() -> Dictionary:
	return {"total": total}


func load_state(state: Dictionary) -> void:
	total = int(state.get("total", 0))
	# Straight to the number rather than through a roll: nothing was earned, a
	# save was opened, and a score counting up from zero is a lie about what
	# just happened. Same reason Collectibles skips the flight on a load.
	_set_shown(total)


# ------------------------------------------------------------------- the HUD --

## Counter under the fruit count, top left. Built in code and parented here so it
## outlives every level. It sits OUTSIDE the game's sub-viewport, so it is drawn
## at the window's real resolution rather than at 320x180 — see systems/screen.gd.
##
## Laid out in a 1280x720 space and scaled down by 4, the same trick DialogueBox
## and the other two counters use.
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "PointsHud"
	_hud.layer = 92  # over the world, under the dialogue box (95)
	_hud.scale = Vector2(0.25, 0.25)
	add_child(_hud)

	_root = Control.new()
	_root.position = ROW
	_root.size = ROW_SIZE
	_root.pivot_offset = Vector2(0.0, ROW_SIZE.y * 0.5)  # punch grows rightward
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_root)

	_label = Label.new()
	_label.size = ROW_SIZE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 30)
	# The neon green of the tag, so the number and the thing that pays into it
	# are visibly the same system — against the warm off-white the fruit and
	# death counters use.
	_label.add_theme_color_override("font_color", Color(0.72, 0.92, 0.38))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_label)

	_hud.visible = Screen.current != null
	_refresh()


## Put the counter straight onto a number, and STOP any roll first.
##
## The kill is the whole reason this is a function. A load or a reset that only
## assigns leaves the running tween holding the numbers it captured when it
## started, and it goes on writing them a frame later — so a slot opened while
## the last award was still counting up comes back showing a number from the run
## you just left. The test that caught it read 1816 where it wanted 2000.
func _set_shown(value: int) -> void:
	if _roll and _roll.is_valid():
		_roll.kill()
	_shown = value
	changed.emit(total)
	_refresh()


func _refresh() -> void:
	if _label != null:
		_label.text = str(_shown)


## Run the displayed number up to `to`. One tween, killed and replaced, so two
## awards in quick succession do not fight over the label.
func _roll_to(to: int) -> void:
	if _label == null:
		_shown = to
		return
	if _roll and _roll.is_valid():
		_roll.kill()
	var from := _shown
	_roll = create_tween()
	_roll.tween_method(func(k: float) -> void:
			_shown = int(round(lerpf(float(from), float(to), k)))
			_refresh(),
		0.0, 1.0, ROLL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## A short knock when the number goes up — enough to catch the eye without
## becoming a thing you look at instead of the room.
func _punch_counter() -> void:
	if _root == null:
		return
	if _punch and _punch.is_valid():
		_punch.kill()
	_root.scale = Vector2(1.18, 1.18)
	_punch = create_tween()
	_punch.tween_property(_root, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pop a "+N" over whatever just paid out.
##
## Positioned the way the flying fruit is: the HUD is authored at 1280x720, so a
## world point has to come through get_global_transform_with_canvas() and be
## divided back out of the layer's own scale.
func _popup(amount: int, source: CanvasItem) -> void:
	if _hud == null or source == null or not is_instance_valid(source) \
			or not source.is_inside_tree():
		return
	var text := "+" + str(amount)
	var tag := Control.new()
	# Named, so a test can find it without guessing at child order or matching a
	# texture — the layer also carries the counter, and the tag is now a Control
	# with a glyph per digit rather than one picture.
	tag.name = "PointsTag"
	var size := Vector2((text.length() - 1) * GLYPH_ADVANCE + GLYPH_CELL.x,
		GLYPH_CELL.y) * POPUP_SCALE
	tag.size = size
	tag.pivot_offset = size * 0.5              # it grows about its middle
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for i in text.length():
		var cell := GLYPH_ORDER.find(text[i])
		if cell < 0:
			continue
		# The sheet is one strip of cells; each glyph shows its own.
		var region := AtlasTexture.new()
		region.atlas = DIGITS
		region.region = Rect2(Vector2(cell * GLYPH_CELL.x, 0.0), GLYPH_CELL)
		var glyph := TextureRect.new()
		glyph.texture = region
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glyph.size = GLYPH_CELL
		glyph.scale = Vector2(POPUP_SCALE, POPUP_SCALE)
		glyph.position = Vector2(i * GLYPH_ADVANCE * POPUP_SCALE, 0.0)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(glyph)

	for where in SPARKS:
		var star := TextureRect.new()
		star.texture = SPARK
		star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.scale = Vector2(POPUP_SCALE, POPUP_SCALE)
		star.position = size * where - Vector2(SPARK.get_size()) * 0.5 * POPUP_SCALE
		tag.add_child(star)

	var at: Vector2 = source.get_global_transform_with_canvas().origin \
		/ _hud.scale.x
	# Centred on what paid, and lifted clear of it, so the thing you just took is
	# not hidden by the number it was worth.
	tag.position = at - size * 0.5 - Vector2(0.0, size.y * 0.55)
	tag.scale = Vector2(0.72, 0.72)
	_hud.add_child(tag)

	var t := create_tween().set_parallel()
	t.tween_property(tag, "position:y", tag.position.y - POPUP_RISE, POPUP_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# A short spring on the way in, then nothing — a tag that keeps moving reads
	# as an animation playing rather than as a thing that happened.
	t.tween_property(tag, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(tag, "modulate:a", 0.0, POPUP_FADE) \
		.set_delay(POPUP_TIME - POPUP_FADE)
	t.chain().tween_callback(tag.queue_free)
