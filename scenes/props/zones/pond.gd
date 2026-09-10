@tool
class_name Pond
extends Area2D
## A swimmable body of water — a traversal zone, not a hazard. Falling into
## it (or simply touching it) switches Player into SWIM; nothing here moves
## him, the same split SlideZone/Ladder use — see player.gd's "ponds" section
## for the physics, and slide_zone.gd's own note for why that split matters
## for frame order (a zone writing velocity from its own _physics_process
## would land either side of the player's move_and_slide() depending on tree
## order).
##
## Same "asked fresh every frame" polling SlideZone/Ladder use, and for the
## same four reasons that note gives: a checkpoint under the surface, a room
## loading with him already in the water, the debug picker dropping him
## there, and the frame right after a teleport all have to work with no
## overlap boundary ever crossed.
##
## The water itself is drawn transparent — every tile in pond_water.png sits
## well under full alpha — so whatever the room painted under the pond stays
## visible through it, and REFRACTED: every tile shares one
## assets/shaders/water_distortion.gdshader material (see that file's own
## header) that samples the screen behind the water at a wobbling, pixel-
## snapped offset, so what shows through visibly ripples instead of sitting
## still under a flat tint. A handful of Fish drift inside too, for the
## "something is alive in here" read. Neither is a hazard: touching a fish
## does nothing, and there is no drowning, no timer, no death here at all.
##
## Drop one in LDtk as a `Pond` entity and stretch it over the water you want;
## FishCount is the only field this prop reads — everything about how he
## moves through the water lives on Player (see its "Swim" export group),
## not here, so two ponds in one world can't disagree about how swimming
## feels.

## Full size of the pond in pixels. LDtk sets this from the box you drag.
@export var size := Vector2(64.0, 24.0):
	set(value):
		size = value
		_update_extents()

## How many ambient Fish to scatter inside it. Purely decorative — see
## scenes/props/Fish.tscn. 0 is a fine, quiet pond.
@export var fish_count := 3:
	set(value):
		fish_count = maxi(value, 0)
		_rebuild_fish()

## The water sheet: TOP/LEFT/RIGHT/BOTTOM container-wall edges (plus the four
## corners) around a shallow/deep fill — tools/gen_pond_water.py, 10 columns
## x 3 animation rows of 8x8. The edges are what make this read as liquid
## actually CONTAINED by whatever it's dropped into (brick, most of the
## time) instead of a translucent rectangle with nothing at its own boundary.
const SHEET := preload("res://assets/props/pond/pond_water.png")
const CELL := 8.0
enum Tile {
	TOP, TOP_LEFT, TOP_RIGHT, LEFT, RIGHT,
	BOTTOM, BOTTOM_LEFT, BOTTOM_RIGHT, FILL_SHALLOW, FILL_DEEP,
}
## Only the TOP-family tiles carry the animated surface shimmer; everything
## else is the same frame on every row (see gen_pond_water.py's own note).
const ANIMATED_TILES := [Tile.TOP, Tile.TOP_LEFT, Tile.TOP_RIGHT]
const FRAMES := 3
## Full shimmer cycles per second.
const SHIMMER_SPEED := 1.4
## A "fill" cell counts as deep once this many rows separate it from the
## surface row — same threshold name and reasoning as WaterLayer.DEEP_AT.
const DEEP_AT := 2

const FISH_SCENE := preload("res://scenes/props/Fish.tscn")

## Refraction — see the shader's own header for why this needs to be a
## shader at all (nothing else in this project warps what's BEHIND a
## transparent sprite, only how much of it shows through). Built ONCE and
## shared by every tile sprite via `use_parent_material`, the same
## "one material, many nodes" shape `_apply_lemon_glow()` uses for its own
## CanvasItemMaterial — cheaper than one ShaderMaterial per 8px tile, and it
## keeps every tile's ripple perfectly in phase with every other.
const WATER_SHADER := preload("res://assets/shaders/water_distortion.gdshader")

var _shape: CollisionShape2D
var _water: Node2D
var _fish_root: Node2D
## [Sprite2D, phase] per surface-row column — the only tiles that animate, so
## _process has nothing to do with the rest of _water's children.
var _shimmer: Array = []
var _clock := 0.0
## The player currently swimming here, so it knows whose swim to end.
var _held: Player


func _ready() -> void:
	collision_layer = 8  # layer 4 "triggers"
	collision_mask = 2   # player only
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_water = Node2D.new()
	_water.name = "Water"
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	_water.material = mat
	add_child(_water)
	_fish_root = Node2D.new()
	_fish_root.name = "Fish"
	add_child(_fish_root)
	_update_extents()


## Nothing here builds anything until _ready has — the same guard
## SlideZone/Ladder use, for the same reason: `size` is set by the LDtk
## importer before this node's own children exist.
func _update_extents() -> void:
	if _shape == null:
		return
	_shape.shape.size = size.max(Vector2(CELL, CELL))
	_rebuild_water()
	_rebuild_fish()


## Lay the water out a cell at a time: TOP along the surface, BOTTOM along
## the container floor, LEFT/RIGHT down the side walls, the four corners
## wherever two of those meet, and a shallow/deep fill everywhere else — the
## depth-gradient AND the "actually contained by a wall" read the brief asks
## for, built the same way SlideZone tiles its own floor. A 1-row pond has no
## floor of its own to draw (TOP already covers the whole thing); a 1-column
## pond has no separate right wall (LEFT covers it) — both are edge cases a
## real Pond is unlikely to be dragged into, but degrading to "just the
## surface" / "just one wall" beats picking arbitrarily between two edges
## that would otherwise land on the same single cell.
func _rebuild_water() -> void:
	if _water == null:
		return
	for old in _water.get_children():
		old.free()  # free, not queue_free — reruns on every drag in the editor
	_shimmer.clear()
	var cols := maxi(int(round(size.x / CELL)), 1)
	var rows := maxi(int(round(size.y / CELL)), 1)
	var top := -size.y * 0.5
	var left := -size.x * 0.5
	for row in rows:
		var is_top := row == 0
		var is_bottom := row == rows - 1 and rows > 1
		for col in cols:
			var is_left := col == 0
			var is_right := col == cols - 1 and cols > 1
			var tile: Tile
			if is_top and is_left:
				tile = Tile.TOP_LEFT
			elif is_top and is_right:
				tile = Tile.TOP_RIGHT
			elif is_top:
				tile = Tile.TOP
			elif is_bottom and is_left:
				tile = Tile.BOTTOM_LEFT
			elif is_bottom and is_right:
				tile = Tile.BOTTOM_RIGHT
			elif is_bottom:
				tile = Tile.BOTTOM
			elif is_left:
				tile = Tile.LEFT
			elif is_right:
				tile = Tile.RIGHT
			else:
				tile = Tile.FILL_DEEP if row >= DEEP_AT else Tile.FILL_SHALLOW
			var sprite := Sprite2D.new()
			sprite.texture = _tile(tile, 0)
			sprite.centered = false
			sprite.position = Vector2(left + col * CELL, top + row * CELL)
			sprite.use_parent_material = true
			_water.add_child(sprite)
			if tile in ANIMATED_TILES:
				# Hashed from its column, not randf() — two shimmer columns
				# should not pulse in lockstep, and the same layout should
				# look the same on every visit (the thought tiles' own rule
				# for exactly this kind of per-cell decorrelated animation).
				var phase := _hash01(col, 0)
				_shimmer.append([sprite, tile, phase])


func _process(delta: float) -> void:
	if _shimmer.is_empty():
		return
	_clock += delta
	for entry in _shimmer:
		var sprite: Sprite2D = entry[0]
		var tile: Tile = entry[1]
		var phase: float = entry[2]
		var t := fmod(_clock * SHIMMER_SPEED + phase, 1.0)
		var frame := clampi(int(t * FRAMES), 0, FRAMES - 1)
		sprite.texture = _tile(tile, frame)


func _tile(which: Tile, frame: int) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = SHEET
	tex.region = Rect2(int(which) * CELL, frame * CELL, CELL, CELL)
	return tex


## Scatter fish_count Fish inside the box. Deterministic placement (hashed
## from each fish's index against the pond's own footprint, not randf()) so a
## given pond looks the same on every visit — DarkThought.reset() and the
## thought-tile clocks make the same call elsewhere in this project.
func _rebuild_fish() -> void:
	if _fish_root == null:
		return
	for old in _fish_root.get_children():
		old.free()
	if Engine.is_editor_hint():
		return  # fish patrol via _process; there is nothing static to preview
	var w := int(size.x)
	var h := int(size.y)
	for i in fish_count:
		# Three INDEPENDENT hashes, not one reused three ways — reusing one
		# would correlate x/y/direction (a fish hashed to the left edge would
		# also always swim the same way), the same reasoning
		# ThoughtHazardLayer._hash's own note gives for keeping speed and
		# phase apart.
		var fx := (_hash01(i, w) - 0.5) * maxf(size.x - 16.0, 4.0)
		var fy := (_hash01(i, h + 1000) - 0.5) * maxf(size.y - 8.0, 2.0)
		var dir := 1 if _hash01(i, w + h + 2000) < 0.5 else -1
		var fish: Fish = FISH_SCENE.instantiate()
		fish.position = Vector2(fx, fy)
		fish.patrol_width = minf(size.x - 8.0, 20.0 + _hash01(i, w + 3000) * 16.0)
		fish.start_dir = dir
		_fish_root.add_child(fish)


## Deterministic float in [0, 1) from two integers — the same integer-mix
## ThoughtHazardLayer._hash() uses for its own per-cell phase/speed, kept as
## its own copy here per this project's self-contained-script convention
## (see gen_pond_water.py's _ramp_from_source for the same call made about a
## different small helper) rather than a cross-class dependency on an
## unrelated system, and deliberately not Godot's built-in hash() — same
## reasoning: independent of anything Godot's own hash implementation might
## change between engine versions.
static func _hash01(a: int, b: int) -> float:
	var n := a * 374761393 + b * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / float(0x7fffffff)


## World Y of this pond's surface — its own top edge, since a Pond is always a
## plain box. Same method name WaterLayer answers (see its own doc for the
## walked, per-column version an irregular painted shape needs), so Player can
## ask whichever zone happens to hold him without knowing which kind it is.
## INF when the point is outside the box, matching WaterLayer's own "not in
## water" answer rather than handing back a surface he is nowhere near.
func surface_y_at(world_pos: Vector2) -> float:
	var top := global_position.y - size.y * 0.5
	var half := size * 0.5
	if absf(world_pos.x - global_position.x) > half.x \
			or absf(world_pos.y - global_position.y) > half.y:
		return INF
	return top


## Who is swimming, asked fresh every frame rather than tracked from
## body_entered/body_exited — see the class doc above for why.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var inside: Player = null
	for body in get_overlapping_bodies():
		if body is Player:
			inside = body
			break
	if inside != null:
		if not inside.swimming():
			inside.enter_swim(self)
			_held = inside
	elif _held != null:
		if is_instance_valid(_held):
			_held.exit_swim(self)
		_held = null
