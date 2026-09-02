extends Node
## Act 2's reskinned hazards: DarkThought/LightThought/GreyThought and
## ConeSpikes with `palette = CHILDHOOD` still kill exactly like the office
## palette does — the reskin changes art only, never the kill contract — and
## really do draw the new sheets, not just silently keep the old ones. Also
## covers the paintable ThoughtHazards tiles: Act 2's own copy of that layer
## points at the new sheet and a painted cell still kills, same mechanism
## tests/thought_tiles_test.gd already proves generically.
##
## Run:  godot --headless res://tests/act2_hazards_test.tscn

const DARK_THOUGHT := preload("res://scenes/props/hazards/DarkThought.tscn")
const LIGHT_THOUGHT := preload("res://scenes/props/hazards/LightThought.tscn")
const GREY_THOUGHT := preload("res://scenes/props/hazards/GreyThought.tscn")
const CONE_SPIKES := preload("res://scenes/props/hazards/ConeSpikes.tscn")
const PLAYER := preload("res://scenes/characters/hooshang/Hooshang.tscn")

var failures: Array[String] = []
var world: Node2D
var player: Player


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	player = PLAYER.instantiate()
	world.add_child(player)
	await _run()


func _run() -> void:
	# --- clouds: office is the default, unaffected --------------------------
	var office: DarkThought = DARK_THOUGHT.instantiate()
	office.position = Vector2(50, 50)
	office.motion = DarkThought.Motion.VERTICAL
	office.amplitude = 0.0
	world.add_child(office)
	await _frames(2)
	_check(office.palette == DarkThought.Palette.OFFICE,
		"a fresh DarkThought defaults to the office palette")
	_check((office.get_node("Cloud") as Sprite2D).texture.atlas == DarkThought.SHEETS[DarkThought.Tone.DARK],
		"...and actually draws the office sheet")

	# --- clouds: CHILDHOOD palette draws the new sheet and still kills ------
	for spec in [
		{"scene": DARK_THOUGHT, "tone": DarkThought.Tone.DARK, "name": "DarkThought"},
		{"scene": LIGHT_THOUGHT, "tone": DarkThought.Tone.LIGHT, "name": "LightThought"},
		{"scene": GREY_THOUGHT, "tone": DarkThought.Tone.GREY, "name": "GreyThought"},
	]:
		var thought: DarkThought = spec["scene"].instantiate()
		thought.position = Vector2(200, 50)
		thought.motion = DarkThought.Motion.VERTICAL
		thought.amplitude = 0.0
		thought.palette = DarkThought.Palette.CHILDHOOD
		world.add_child(thought)
		await _frames(2)
		var sprite := thought.get_node("Cloud") as Sprite2D
		_check(sprite.texture.atlas == DarkThought.SHEETS_CHILDHOOD[spec["tone"]],
			"%s(CHILDHOOD) draws the Act 2 sheet, not the office one" % spec["name"])
		_check(sprite.texture.atlas != DarkThought.SHEETS[spec["tone"]],
			"...and it is genuinely a different texture")

		player.input_locked = true
		player.velocity = Vector2.ZERO
		player.global_position = thought.position
		await _frames(3)
		_check(player.state == Player.State.DEAD,
			"%s(CHILDHOOD) still kills on contact" % spec["name"])
		player.respawn(Vector2(-500, -500))
		# respawn() grants a brief 0.1s (6-frame) invulnerability window so a
		# hazard he respawns on top of cannot instant-kill him again — real for
		# a checkpoint, but it would also mask the NEXT hazard's own kill check
		# here if not cleared, since this loop moves straight to another test.
		player.invulnerable_timer = 0.0
		await _frames(2)
		player.input_locked = false
		thought.queue_free()

	# --- cone spikes: CHILDHOOD palette draws the new sheet, still kills ----
	var spikes: ConeSpikes = CONE_SPIKES.instantiate()
	spikes.position = Vector2(400, 200)
	spikes.facing = ConeSpikes.Facing.UP
	spikes.size = Vector2(8.0, ConeSpikes.CELL)
	spikes.palette = ConeSpikes.Palette.CHILDHOOD
	world.add_child(spikes)
	await _frames(2)
	var cone_sprite := (spikes.get_node("Cones") as Node2D).get_child(0) as Sprite2D
	_check(cone_sprite.texture.atlas == ConeSpikes.SHEETS_CHILDHOOD[ConeSpikes.Facing.UP],
		"ConeSpikes(CHILDHOOD) draws the Act 2 sheet")
	_check(cone_sprite.texture.atlas != ConeSpikes.SHEETS[ConeSpikes.Facing.UP],
		"...and it is genuinely a different texture from the office one")

	player.input_locked = true
	player.velocity = Vector2.ZERO
	player.global_position = spikes.position
	await _frames(3)
	_check(player.state == Player.State.DEAD, "ConeSpikes(CHILDHOOD) still kills on contact")
	player.respawn(Vector2(-500, -500))
	await _frames(2)
	player.input_locked = false

	# --- the import hook: ChildhoodPalette field reaches the props ----------
	var importer = load("res://scripts/ldtk_entities_post_import.gd").new()
	var built_dark: DarkThought = importer._build_thought({
		"identifier": "DarkThought", "position": Vector2.ZERO, "size": Vector2.ZERO,
		"fields": {"ChildhoodPalette": 1.0},
	})
	_check(built_dark.palette == DarkThought.Palette.CHILDHOOD,
		"import: ChildhoodPalette 1.0 reaches DarkThought as CHILDHOOD")
	built_dark.free()
	var unset_dark: DarkThought = importer._build_thought({
		"identifier": "DarkThought", "position": Vector2.ZERO, "size": Vector2.ZERO,
		"fields": {},
	})
	_check(unset_dark.palette == DarkThought.Palette.OFFICE,
		"...and an unset field (every Act 1 placement) falls back to OFFICE")
	unset_dark.free()
	var built_cone: ConeSpikes = importer._build_cone_spikes({
		"identifier": "ConeSpikes", "position": Vector2.ZERO, "size": Vector2(8.0, 8.0),
		"fields": {"ChildhoodPalette": 1.0},
	}, ConeSpikes.Facing.UP)
	_check(built_cone.palette == ConeSpikes.Palette.CHILDHOOD,
		"import: ChildhoodPalette 1.0 reaches ConeSpikes as CHILDHOOD")
	built_cone.free()
	var unset_cone: ConeSpikes = importer._build_cone_spikes({
		"identifier": "ConeSpikes", "position": Vector2.ZERO, "size": Vector2(8.0, 8.0),
		"fields": {},
	}, ConeSpikes.Facing.UP)
	_check(unset_cone.palette == ConeSpikes.Palette.OFFICE,
		"...and an unset field falls back to OFFICE  [ConeSpikes too]")
	unset_cone.free()

	# --- the paintable ThoughtHazards tiles: Act 2's own sheet, still kills --
	await _check_thought_tiles()

	if failures.is_empty():
		print("ACT2 HAZARDS TEST: ALL PASS")
	else:
		print("ACT2 HAZARDS TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Same mechanism tests/thought_tiles_test.gd already proves generically
## (pass-through collision, tile-overlap kill) — this only has to prove Act 2's
## OWN copy of the layer points at the new sheet and that reskin did not
## disturb the mechanism.
func _check_thought_tiles() -> void:
	SaveGame.slot = -1
	var act2_world: LdtkWorld = load("res://ldtk/Act2World.tscn").instantiate()
	LdtkWorld.debug_start_room = "Act2_Level_0"
	world.add_child(act2_world)
	await get_tree().process_frame
	await get_tree().process_frame

	var room := act2_world.current_room
	_check(room != null, "Act 2's world starts in Act2_Level_0")
	if room == null:
		return
	var layer := room.get_node_or_null("ThoughtHazards") as TileMapLayer
	_check(layer != null, "ThoughtHazards layer exists in the Act 2 room")
	if layer == null:
		return
	# The importer builds ONE TileSetSource per tileset DEFINITION in the whole
	# project (build_tilesets loops every definitions.tilesets key), not one
	# per layer that actually uses it — so layer.tile_set holds every source
	# the project defines, including ones no layer currently paints with
	# (Act 2's file still carries a few unused defs borrowed from Act 1's
	# scaffolding). Index 0 is therefore NOT reliably "this layer's source";
	# find the one whose texture is actually Act 2's sludge sheet.
	var source_id := -1
	var tex_path := ""
	for i in layer.tile_set.get_source_count():
		var id := layer.tile_set.get_source_id(i)
		var source := layer.tile_set.get_source(id)
		if source is TileSetAtlasSource \
				and (source as TileSetAtlasSource).texture.resource_path.contains("act2_thought_tiles"):
			source_id = id
			tex_path = (source as TileSetAtlasSource).texture.resource_path
			break
	_check(tex_path.contains("act2_thought_tiles"),
		"...and its tileset includes Act 2's own sheet, not just the office one  [%s]" % tex_path)

	var act2_player := act2_world.player
	var cell := layer.local_to_map(layer.to_local(act2_player.global_position))
	_check(not act2_world._in_thought_tile(), "empty cell is not a hazard")
	if source_id != -1:
		layer.set_cell(cell, source_id, Vector2i(0, 0))
		_check(act2_world._in_thought_tile(),
			"a painted cell on Act 2's own sheet is still detected as a hazard")
		act2_world._physics_process(1.0 / 60.0)
		_check(act2_player.state == Player.State.DEAD,
			"...and still kills on the next physics tick")
		layer.erase_cell(cell)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
