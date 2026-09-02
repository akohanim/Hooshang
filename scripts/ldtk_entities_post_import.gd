@tool
## LDtk entity post-import hook (see STYLE_GUIDE.md §9). Wired into every
## .ldtk file's import options as `entities_post_import`. Runs once per
## Entities layer and replaces the raw LDtk entity data with real, working
## scene nodes — same prefabs/scripts every hand-built level uses.
##
## Entity data shape (see addons/ldtk-importer/src/util/layer-util.gd):
##   {iid, identifier, smart_color, size, position, pivot, fields, definition}
## All entities here use a center pivot (0.5, 0.5), so `position` is each
## entity's center point.

const DOOR_SCENE := preload("res://scenes/props/Door.tscn")
const CHECKPOINT_SCENE := preload("res://scenes/props/Checkpoint.tscn")
const HAZARD_SCENE := preload("res://scenes/props/hazards/Hazard.tscn")
const GLASS_SPIKES_SCENE := preload("res://scenes/props/hazards/GlassSpikes.tscn")
const CONE_SPIKES_SCENE := preload("res://scenes/props/hazards/ConeSpikes.tscn")
## The two tones of thought. One prop, one script, one set of fields — the only
## difference is which sheet the cloud is drawn from, so they are two LDtk
## entities purely so the editor shows you which one you placed.
const THOUGHT_SCENES := {
	"DarkThought": preload("res://scenes/props/hazards/DarkThought.tscn"),
	"LightThought": preload("res://scenes/props/hazards/LightThought.tscn"),
	"GreyThought": preload("res://scenes/props/hazards/GreyThought.tscn"),
}
const PLATFORM_SCENE := preload("res://scenes/props/platforms/Platform.tscn")
const CRUMBLING_SCENE := preload("res://scenes/props/platforms/CrumblingPlatform.tscn")
const SPRING_PLATFORM_SCENE := preload("res://scenes/props/platforms/SpringPlatform.tscn")
const MAGIC_CARPET_SCENE := preload("res://scenes/props/zones/MagicCarpet.tscn")
const KEY_SCENE := preload("res://scenes/props/Key.tscn")
const JAMSHID_CAGE_SCENE := preload("res://scenes/props/JamshidCage.tscn")
const SLIDE_ZONE_SCENE := preload("res://scenes/props/zones/SlideZone.tscn")
const LADDER_SCENE := preload("res://scenes/props/zones/Ladder.tscn")
const CONVEYOR_BELT_SCENE := preload("res://scenes/props/zones/ConveyorBelt.tscn")
const DARKSHANG_SCENE := preload("res://scenes/props/chase/Darkshang.tscn")
const SURGE_POINT_SCENE := preload("res://scenes/props/chase/SurgePointTrigger.tscn")
const SAFE_ZONE_SCENE := preload("res://scenes/props/chase/SafeZoneTrigger.tscn")
const DARKSHANG_TRIGGER_SCENE := preload("res://scenes/props/chase/DarkshangTrigger.tscn")
const CEILING_LIGHT_SCENE := preload("res://scenes/props/lighting/CeilingLight.tscn")
const CEILING_PANEL_SCENE := preload("res://scenes/props/lighting/CeilingPanel.tscn")
const RUMI_TRIGGER_SCRIPT := preload("res://scripts/ldtk_rumi_trigger.gd")
const LDTK_DOOR_SCRIPT := preload("res://scripts/ldtk_door.gd")
const EXIT_SIGN_SCENE := preload("res://scenes/props/ExitSign.tscn")
const EXIT_CEILING_SIGN_SCENE := preload("res://scenes/props/ExitSignCeiling.tscn")
const NOTE_TILE_SCENE := preload("res://scenes/props/NoteTile.tscn")
const LEMON_SCENE := preload("res://scenes/props/Lemon.tscn")
const MYSTERY_BOX_SCENE := preload("res://scenes/props/MysteryBox.tscn")
const RUMI_FRAMES := preload("res://assets/rumi_frames.tres")
const RUMI_LIGHT_TEXTURE := preload("res://assets/light_radial.png")
const RUMI_GOLD := Color(1.0, 0.82, 0.42, 1.0)

# Door's own origin is its TOP-LEFT corner (matches Door.tscn's Frame content
# bbox, ~27x42 after the door_frame.png crop + 0.4 scale), not centered like
# the LDtk marker — offset so the frame visually centers on the placed point.
const DOOR_VISUAL_SIZE := Vector2(27.2, 42.4)


func post_import(entity_layer: LDTKEntityLayer) -> LDTKEntityLayer:
	var player_spawn_count := 0
	for data: Dictionary in entity_layer.entities:
		match data.identifier:
			"PlayerStart":
				player_spawn_count += 1
				var spawn_id := _field_str(data, "SpawnID")
				var marker := Marker2D.new()
				# First one found is the default spawn; extras (multi-entrance
				# support, keyed by SpawnID) aren't wired to anything yet —
				# kept as markers so the data isn't lost once that's built.
				marker.name = "PlayerStart" if player_spawn_count == 1 else \
					"PlayerStart_%s" % (spawn_id if spawn_id != "" else str(player_spawn_count))
				marker.position = data.position
				marker.set_meta("spawn_id", spawn_id)
				entity_layer.add_child(marker)
			"Door":
				var door: Node2D = DOOR_SCENE.instantiate()
				# LdtkDoor extends Door — the swing is unchanged, this just adds
				# the one-time "open onto the void, walk through" story beat.
				door.set_script(LDTK_DOOR_SCRIPT)
				door.position = Vector2(data.position) - DOOR_VISUAL_SIZE * 0.5
				door.set_meta("target_spawn_id", _field_str(data, "TargetSpawnID"))
				# persistent = true so the group survives being packed into the .scn
				door.add_to_group("story_door", true)
				entity_layer.add_child(door)
			"Checkpoint":
				var checkpoint: Area2D = CHECKPOINT_SCENE.instantiate()
				checkpoint.position = data.position
				checkpoint.set_meta("checkpoint_id", _field_str(data, "CheckpointID"))
				entity_layer.add_child(checkpoint)
			"Hazard":
				var hazard: Area2D = HAZARD_SCENE.instantiate()
				hazard.position = data.position
				hazard.size = Vector2(data.size)
				entity_layer.add_child(hazard)
			# One entity per surface, so which way the points aim is chosen by
			# picking the right entity rather than by remembering a field.
			# Both platforms are dragged out to a WIDTH in LDtk; the height is
			# forced to one cell by the prop itself, so an author who drags the
			# handle diagonally still gets a ledge rather than a wall.
			"Platform":
				entity_layer.add_child(_build_platform(data, PLATFORM_SCENE))
			"CrumblingPlatform":
				entity_layer.add_child(_build_platform(data, CRUMBLING_SCENE))
			# Act 2's bounce pad. Same one-cell/@tool/tile-laying shape as
			# Platform/CrumblingPlatform (SpringPlatform extends Platform), so
			# it reuses the same builder — see spring_platform.gd.
			"SpringPlatform":
				entity_layer.add_child(_build_platform(data, SPRING_PLATFORM_SCENE))
			"GlassSpikes":
				entity_layer.add_child(_build_glass_spikes(data, GlassSpikes.Facing.UP))
			"GlassSpikesCeiling":
				entity_layer.add_child(_build_glass_spikes(data, GlassSpikes.Facing.DOWN))
			"GlassSpikesLeftWall":
				entity_layer.add_child(_build_glass_spikes(data, GlassSpikes.Facing.RIGHT))
			"GlassSpikesRightWall":
				entity_layer.add_child(_build_glass_spikes(data, GlassSpikes.Facing.LEFT))
			# The single-cell version of the same idea: 8px conical spikes, for a
			# floor you want threatened without giving up two cells of the room's
			# height to the hazard. Four entities for the same reason the glass
			# ones are four — a direction FIELD is a thing you can forget to set.
			"ConeSpikes":
				entity_layer.add_child(_build_cone_spikes(data, ConeSpikes.Facing.UP))
			"ConeSpikesCeiling":
				entity_layer.add_child(_build_cone_spikes(data, ConeSpikes.Facing.DOWN))
			"ConeSpikesLeftWall":
				entity_layer.add_child(_build_cone_spikes(data, ConeSpikes.Facing.RIGHT))
			"ConeSpikesRightWall":
				entity_layer.add_child(_build_cone_spikes(data, ConeSpikes.Facing.LEFT))
			# The full-size ceiling run — the fixture standing in room 2, not
			# the 8px paint tiles. Dragged to a WIDTH, which becomes the number
			# of 24px cells; the prop rounds that to an odd count, because the
			# panel is the middle cell and an even run has no middle.
			"CeilingPanel":
				entity_layer.add_child(_build_ceiling_panel(data))
			# The light of a ceiling panel, placed by hand. Painted panels are
			# lit by the import already (ldtk_level_post_import.gd) — this is
			# for the ones off that rhythm, and for lighting a plain cell.
			"CeilingLight":
				var lamp: CeilingPanel = CEILING_LIGHT_SCENE.instantiate()
				lamp.position = data.position
				_light_fields(lamp, data)
				entity_layer.add_child(lamp)
			# A hazard that MOVES, and the one entity here whose direction is a
			# field rather than its own entity. Two names, one prop: the tones
			# are split so LDtk shows which is which, nothing more. See
			# _build_thought.
			"DarkThought", "LightThought", "GreyThought":
				entity_layer.add_child(_build_thought(data))
			"SlideZone":
				entity_layer.add_child(_build_slide_zone(data))
			# One entity per direction, so which way a belt runs is chosen by
			# picking the right entity rather than by remembering a field — the
			# same reason the note tiles are five and the glass spikes four. The
			# bare "ConveyorBelt" is the name these had before they were split;
			# every one of them ran right.
			"ConveyorBelt_Right", "ConveyorBelt":
				entity_layer.add_child(
					_build_conveyor_belt(data, ConveyorBelt.Direction.RIGHT))
			"ConveyorBelt_Left":
				entity_layer.add_child(
					_build_conveyor_belt(data, ConveyorBelt.Direction.LEFT))
			# Act 2's rideable flying carpet — see _build_magic_carpet.
			"MagicCarpet":
				entity_layer.add_child(_build_magic_carpet(data))
			# Act 2's quest key — see _build_key.
			"Key":
				entity_layer.add_child(_build_key(data))
			# Act 2's locked barrier to Jamshid — see _build_jamshid_cage.
			"JamshidCage":
				entity_layer.add_child(_build_jamshid_cage(data))
			# The boss chase (Level_14). Three entities: where the shadow starts,
			# where he lunges, and where it ends.
			"DarkshangSpawn":
				entity_layer.add_child(_build_darkshang(data))
			"SurgePoint":
				entity_layer.add_child(_build_surge_point(data))
			"SafeZone":
				entity_layer.add_child(_build_safe_zone(data))
			"DarkshangTrigger":
				entity_layer.add_child(_build_darkshang_trigger(data))
			"RumiTrigger":
				entity_layer.add_child(_build_rumi_trigger(data))
			"Exit":
				entity_layer.add_child(_build_exit(data))
			# A ceiling-mounted twin of Exit — same trigger, group and NextRoom
			# meta, just an 8x16 sign hanging from the ceiling instead of a
			# doorway. See _build_exit_ceiling.
			"ExitCeiling":
				entity_layer.add_child(_build_exit_ceiling(data))
			# A climbable rail. Stretch it vertically in LDtk; width is fixed at
			# one cell. See scenes/props/zones/ladder.gd for how gripping it
			# works.
			"Ladder":
				entity_layer.add_child(_build_ladder(data))
			# Hand-placed collectible. Nothing to configure — the prefab owns its
			# own art, pickup rule and pop; the running total lives in the
			# Collectibles autoload so it survives the room and the level.
			"Lemon":
				var pom: Area2D = LEMON_SCENE.instantiate()
				pom.position = data.position
				entity_layer.add_child(pom)
			# The Mario-style "?" block. Not resizable — like DarkThought, the
			# art is a fixed 16x16, so a dragged handle could only ever promise
			# a bigger block than the one that is actually solid.
			"MysteryBox":
				entity_layer.add_child(_build_mystery_box(data))
			# Five separate entities (MusicNote1..MusicNote5) rather than one
			# with an index field: LDtk colours entities per DEFINITION, so a
			# shared one draws every tile the same and any instance whose field
			# you forget silently becomes note 1 — which broke the first pass.
			"MusicNote1", "MusicNote2", "MusicNote3", "MusicNote4", "MusicNote5":
				var tile: StaticBody2D = NOTE_TILE_SCENE.instantiate()
				tile.position = data.position
				tile.note_index = int(str(data.identifier).substr(9))
				entity_layer.add_child(tile)
			"MusicNote":  # legacy single-entity form, kept so old levels still load
				var tile: StaticBody2D = NOTE_TILE_SCENE.instantiate()
				tile.position = data.position
				tile.note_index = _field_int(data, "NoteIndex", 1)
				entity_layer.add_child(tile)
	return entity_layer


## A strip of broken glass on one of the four surfaces. Stretch the entity ALONG
## that surface in LDtk and the prefab lays out that many cells of shards; the
## other dimension is forced to one cell, however the entity got dragged.
##
## Its own function rather than four inline branches because the length is the
## whole point of these entities, and Vector2(data.size) quietly carrying the
## across-axis through would put the kill box somewhere nobody asked for.
## A platform, at the width it was dragged to.
##
## `position` is the entity's CENTRE, the same as every other sized entity here
## (see _build_glass_spikes), and Platform centres its box and art to match.
func _build_platform(data: Dictionary, scene: PackedScene) -> StaticBody2D:
	var plat: StaticBody2D = scene.instantiate()
	plat.position = data.position
	plat.size = Vector2(Vector2(data.size).x, Platform.CELL)
	return plat


## A ceiling run, at the width it was dragged to.
##
## `position` is the entity's CENTRE, like every other sized entity here, and
## CeilingPanel centres its run on that too — so the panel lands on the point
## you placed rather than half a run away from it.
func _build_ceiling_panel(data: Dictionary) -> CeilingPanel:
	var run: CeilingPanel = CEILING_PANEL_SCENE.instantiate()
	run.position = data.position
	run.run_tiles = maxi(int(roundf(Vector2(data.size).x / CeilingPanel.TILE.x)), 1)
	_light_fields(run, data)
	# ABOVE THE ROOM'S OWN TILES. The Entities layer is built before Collisions
	# and both sit at z 0, so a run placed over painted ceiling would be drawn
	# and then covered by the paint — present, correct, and invisible, which is
	# the hardest kind of missing thing to chase. z 1 clears the tile layers and
	# still leaves it behind Foreground, which is the band for scenery the
	# player passes in front of.
	run.z_index = 1
	return run


## Per-instance lighting, from the entity's own LDtk fields.
##
## THE DEFAULTS IN LDTK MATCH THE PROP'S OWN, which is what makes placing one
## harmless: an untouched instance is the fixture in room 2, because the number
## LDtk hands over is the number the scene already had.
## tools/ldtk_fix_light_fields.py reads both .tscn files to keep them level and
## refuses to run if any of the six disagree.
##
## Each read still falls back to the prop's value, for entities placed BEFORE
## these fields existed: their instances carry no field at all, and a missing
## one must leave the prop alone rather than become 0.0 — a light that is off
## while looking configured.
##
## The vocabulary is LIGHTING.md's: energy is brightness, scale is the radius at
## 64px per 1.0, and the two ENERGIES are different jobs — the panel is how
## bright the fitting looks, the pool is how far its light carries.
func _light_fields(node: CeilingPanel, data: Dictionary) -> void:
	# Whole cells, so it is rounded rather than truncated: LDtk hands this over
	# as a Float (the only numeric type it has ever written in this project),
	# and int(-0.9) is 0 where round(-0.9) is the -1 that was typed.
	node.panel_offset = roundi(_field_float(data, "PanelOffset", node.panel_offset))
	node.panel_energy = _field_float(data, "PanelEnergy", node.panel_energy)
	node.light_energy = _field_float(data, "PoolEnergy", node.light_energy)
	node.light_scale = _field_float(data, "PoolScale", node.light_scale)
	node.pool_drop = _field_float(data, "PoolDrop", node.pool_drop)
	# Flicker is a NUMBER here rather than a checkbox with a number under it.
	# LDtk has only ever written String and Float fields in this project, and a
	# Bool written from a guessed shape is what crashed the editor once already;
	# 0 reads as "steady" perfectly well.
	node.motion_range = _field_float(data, "MotionRange", node.motion_range)
	node.motion_fade = _field_float(data, "MotionFade", node.motion_fade)
	var amount := _field_float(data, "FlickerAmount", 0.0)
	node.flickers = amount > 0.0
	if node.flickers:
		node.flicker_amount = amount
		node.flicker_speed = _field_float(data, "FlickerSpeed", node.flicker_speed)


func _build_glass_spikes(data: Dictionary, facing: GlassSpikes.Facing) -> Area2D:
	var spikes: Area2D = GLASS_SPIKES_SCENE.instantiate()
	spikes.position = data.position
	spikes.facing = facing
	var drawn := Vector2(data.size)
	var wall := facing == GlassSpikes.Facing.RIGHT or facing == GlassSpikes.Facing.LEFT
	spikes.size = Vector2(GlassSpikes.CELL, drawn.y) if wall \
		else Vector2(drawn.x, GlassSpikes.CELL)
	return spikes


## The 8px spikes. Same shape as _build_glass_spikes and the same axis forcing,
## against ConeSpikes.CELL (8) rather than GlassSpikes.CELL (16) — which is the
## one line that must not be copied across, because a strip built at the wrong
## cell size still imports, still kills, and is simply drawn at twice the length
## somebody dragged.
##
## The axis the strip does NOT run along is forced to one cell, so a handle
## dragged diagonally in LDtk still yields a strip rather than a block.
func _build_cone_spikes(data: Dictionary, facing: ConeSpikes.Facing) -> Area2D:
	var spikes: Area2D = CONE_SPIKES_SCENE.instantiate()
	spikes.position = data.position
	spikes.facing = facing
	var drawn := Vector2(data.size)
	var wall := facing == ConeSpikes.Facing.RIGHT or facing == ConeSpikes.Facing.LEFT
	spikes.size = Vector2(ConeSpikes.CELL, drawn.y) if wall \
		else Vector2(drawn.x, ConeSpikes.CELL)
	# Same "unset/0 = Act 1's office look" convention as _build_thought's
	# ChildhoodPalette read above — only Act 2's own copies of the four
	# ConeSpikes* defs carry this field, so Act 1's placements are untouched.
	spikes.palette = ConeSpikes.Palette.CHILDHOOD \
		if _field_float(data, "ChildhoodPalette", 0.0) > 0.0 \
		else ConeSpikes.Palette.OFFICE
	return spikes


## A drifting cloud that kills on contact, at the path it was tuned to.
##
## THE OPPOSITE CALL FROM THE SPIKE STRIPS, deliberately. Those are four entities
## each because direction there is a binary you can forget to set and the failure
## is silent — spikes growing out of a ceiling upside down. Motion here is
## NUMBERS (how far, how fast, how far into the cycle), and tuning belongs on the
## instance for the reason _build_slide_zone gives: two thoughts in one room can
## legitimately want different paths, which is the case an entity-per-variant
## cannot serve. A thought whose Motion nobody set still visibly drifts, so there
## is no silent wrong answer to design around.
##
## Motion is read with _field_str and NOT _field_int: an LDtk enum crosses the
## boundary as the value's STRING id (addons/ldtk-importer/src/util/field-util.gd
## matches `LocalEnum.<name>` and hands back `value.id`), so an integer read of it
## is 0 for every mode and every thought in the world drifts vertically.
##
## Clockwise is a Float because LDtk has only ever written String and Float
## fields in this project and a Bool from a guessed shape crashed the editor once
## already — the FlickerAmount precedent, where 0 means off. Anything above zero
## is clockwise.
##
## Size is NOT read. The entity is 16x16 and not resizable, and the kill box is
## derived from the art in dark_thought.gd; taking Vector2(data.size) through
## would let a future stretched instance promise a bigger hazard than the one
## that actually kills.
func _build_thought(data: Dictionary) -> Area2D:
	# By identifier, so the two tones cannot be told apart by anything except
	# which entity was placed — and so a test can drive this the way the importer
	# does, with a name, rather than being handed the answer as an argument.
	var scene: PackedScene = THOUGHT_SCENES[data.identifier]
	var thought: DarkThought = scene.instantiate()
	thought.position = data.position
	match _field_enum(data, "Motion"):
		"Horizontal": thought.motion = DarkThought.Motion.HORIZONTAL
		"Circle": thought.motion = DarkThought.Motion.CIRCLE
		"Linear": thought.motion = DarkThought.Motion.LINEAR
		# Vertical, and also the empty string an untouched field arrives as —
		# which is the prop's own default, so a thought placed before this field
		# existed still moves rather than standing still looking configured.
		_: thought.motion = DarkThought.Motion.VERTICAL
	# absf on the amplitude: the sign belongs to `phase`, so a negative typed
	# here is a distance somebody wrote the wrong way round, not a still hazard.
	thought.amplitude = absf(_field_float(data, "Amplitude", thought.amplitude))
	thought.speed = _field_float(data, "Speed", thought.speed)
	thought.phase = _field_float(data, "Phase", thought.phase)
	thought.clockwise = _field_float(data, "Clockwise", 1.0) > 0.0
	thought.angle = _field_float(data, "Angle", thought.angle)
	# Unset counts as ON: every thought placed before this field existed has no
	# value for it, and a hazard that quietly went dark would be worse than one
	# that ignored the setting.
	thought.glow = _field_float(data, "Glow", 1.0) > 0.0
	# Unset (or 0) counts as Act 1's office palette — see DarkThought.Palette's
	# doc and tools/ldtk_add_act2_palette_field.py. Only Act 2's own copy of
	# this entity def carries the field at all; Act 1 has no ChildhoodPalette
	# field to read, so _field_float's fallback is what keeps every Act 1
	# thought on the office look with zero change to its own placement data.
	thought.palette = DarkThought.Palette.CHILDHOOD \
		if _field_float(data, "ChildhoodPalette", 0.0) > 0.0 \
		else DarkThought.Palette.OFFICE
	# ABOVE THE ROOM'S OWN TILES, for the reason _build_ceiling_panel gives: the
	# Entities layer is built before Collisions and both sit at z 0, so anything
	# that passes in front of painted brick is drawn and then covered by the
	# paint. A ceiling run merely looks wrong that way; a hazard that vanishes
	# behind the wall it is drifting across is one you die to for no visible
	# reason.
	thought.z_index = 1
	return thought


## A Mario-style "?" block, at the point it was placed. `MushroomType` picks
## which power a bump gives up — read with _field_enum, not _field_str, for
## the same reason _build_thought reads Motion that way: an LDtk enum crosses
## the boundary QUALIFIED ("MushroomType.BlackWhite"), never bare, and
## matching the bare name against that misses every value and silently falls
## through to the default.
func _build_mystery_box(data: Dictionary) -> MysteryBox:
	var box: MysteryBox = MYSTERY_BOX_SCENE.instantiate()
	box.position = data.position
	match _field_enum(data, "MushroomType"):
		# Only one power exists today; the explicit branch (rather than just
		# the fallback below) is what a second one slots into.
		"BlackWhite": box.mushroom_type = Mushroom.MushroomType.BLACK_WHITE
		_: box.mushroom_type = Mushroom.MushroomType.BLACK_WHITE
	return box


## A stretch of floor that will not hold him. Unlike the spike entities, this one
## DOES read fields: angle, control_strength and speed_ramp are tuning, and
## tuning belongs on the instance — two chutes in one room can legitimately want
## different numbers, which is exactly the case an entity-per-variant cannot
## serve.
##
## Every field falls back to the prefab's own default, so a zone placed before
## the fields were added to the LDtk definition still behaves like a slide
## rather than like a zone with an angle of zero.
func _build_slide_zone(data: Dictionary) -> Area2D:
	var zone: Area2D = SLIDE_ZONE_SCENE.instantiate()
	zone.position = data.position
	zone.size = Vector2(data.size)
	zone.angle = _field_float(data, "angle", zone.angle)
	zone.control_strength = clampf(
		_field_float(data, "control_strength", zone.control_strength), 0.0, 1.0)
	zone.speed_ramp = maxf(_field_float(data, "speed_ramp", zone.speed_ramp), 0.0)
	return zone


## A rideable flying carpet. `position` is the entity's centre, like every
## other sized entity here; MagicCarpet centres its box and tile-laying on
## that too. Every field falls back to the prefab's own default, so a carpet
## placed before a field existed still behaves (RIDE, drifting right) rather
## than standing dead still.
func _build_magic_carpet(data: Dictionary) -> Area2D:
	var carpet: Area2D = MAGIC_CARPET_SCENE.instantiate()
	carpet.position = data.position
	carpet.size = Vector2(Vector2(data.size).x, MagicCarpet.TILE.y)
	# CarpetPattern crosses the boundary QUALIFIED, same reason _build_thought
	# reads Motion with _field_enum and not _field_str — see that function's
	# doc for what happens if this is gotten wrong.
	match _field_enum(data, "CarpetPattern"):
		"Bob": carpet.pattern = MagicCarpet.CarpetPattern.BOB
		"Sweep": carpet.pattern = MagicCarpet.CarpetPattern.SWEEP
		"Bounce": carpet.pattern = MagicCarpet.CarpetPattern.BOUNCE
		_: carpet.pattern = MagicCarpet.CarpetPattern.RIDE
	carpet.speed = _field_float(data, "Speed", carpet.speed)
	carpet.amplitude = absf(_field_float(data, "Amplitude", carpet.amplitude))
	carpet.steer_range = absf(_field_float(data, "SteerRange", carpet.steer_range))
	return carpet


## One of the four quest keys, at the point it was placed. Not resizable —
## like Lemon/MysteryBox, the art is a fixed size, so a dragged handle could
## only ever promise a bigger pickup than the one that actually collects.
func _build_key(data: Dictionary) -> Area2D:
	var key: Area2D = KEY_SCENE.instantiate()
	key.position = data.position
	key.key_id = _field_str(data, "KeyID")
	return key


## The locked barrier to Jamshid. No fields — whether it is open is entirely
## derived from Act2Quest.all_keys_collected() at runtime (see
## jamshid_cage.gd), so there is nothing here to read from the instance.
func _build_jamshid_cage(data: Dictionary) -> StaticBody2D:
	var cage: StaticBody2D = JAMSHID_CAGE_SCENE.instantiate()
	cage.position = data.position
	return cage


## A stretch of floor that walks. Stretch the entity ALONG the floor row it
## covers; it is one cell tall by definition (resizableY is off in LDtk), so the
## drawn box is the belt surface and the prefab grows its own trigger upward
## from there to catch whoever is standing on it.
##
## Both fields fall back to the prefab's own defaults, so a belt placed before
## the fields existed still runs right at 60 rather than standing still.
func _build_conveyor_belt(data: Dictionary, direction: ConveyorBelt.Direction) -> Area2D:
	var belt: Area2D = CONVEYOR_BELT_SCENE.instantiate()
	belt.position = data.position
	belt.size = Vector2(data.size)
	belt.direction = direction
	# absf, not maxf: the sign belongs to `direction`, so a negative typed into
	# the speed field is a magnitude someone got the wrong way round, not a stop.
	belt.speed = absf(_field_float(data, "speed", belt.speed))
	return belt



## Where the shadow is standing when the chase starts. A point entity with no
## fields: everything about how he behaves is tuning on the prefab, and tuning
## that differs per instance is tuning for a mechanic that has more than one
## instance — there is one Darkshang.
func _build_darkshang(data: Dictionary) -> Area2D:
	var shadow: Area2D = DARKSHANG_SCENE.instantiate()
	shadow.position = data.position
	return shadow


## The threshold that starts the chase: he appears, a beat plays, he begins to
## move. Separate entity from DarkshangSpawn because where he comes FROM and when
## he comes are different questions — see darkshang_trigger.gd.
func _build_darkshang_trigger(data: Dictionary) -> Area2D:
	var trigger: Area2D = DARKSHANG_TRIGGER_SCENE.instantiate()
	trigger.position = data.position
	trigger.size = Vector2(data.size)
	# Empty (or absent) keeps the prefab's own beat rather than silencing it —
	# _field_str has no fallback of its own, and a trigger placed before the
	# field existed should still play the reveal.
	var beat := _field_str(data, "dialogue_id")
	if beat != "":
		trigger.dialogue_id = beat
	return trigger


## The line in a chase where the shadow lunges. Stretch the entity across the
## corridor it should cover — a surge point the player can jump over is one he
## will jump over, so it usually wants to be full height.
##
## Both fields are tuning and therefore per-instance: two surge points in one
## room can legitimately want different lengths and different bites, which is the
## case an entity-per-variant cannot serve. Each falls back to the prefab's own
## default, so a point placed before the fields were added to the LDtk definition
## still surges rather than surging for zero seconds at zero intensity — which
## would look configured and do nothing.
func _build_surge_point(data: Dictionary) -> Area2D:
	var point: Area2D = SURGE_POINT_SCENE.instantiate()
	point.position = data.position
	var drawn := Vector2(data.size)
	point.size = drawn if drawn != Vector2.ZERO else point.size
	point.surge_duration = maxf(
		_field_float(data, "surge_duration", point.surge_duration), 0.0)
	point.surge_intensity = clampf(
		_field_float(data, "surge_intensity", point.surge_intensity), 0.0, 1.0)
	return point


## Where the chase ends. `end_dialogue_id` names the beat that plays; an empty
## one is legitimate (the signal still fires), so unlike the numbers above there
## is nothing to fall back to.
func _build_safe_zone(data: Dictionary) -> Area2D:
	var zone: Area2D = SAFE_ZONE_SCENE.instantiate()
	zone.position = data.position
	var drawn := Vector2(data.size)
	zone.size = drawn if drawn != Vector2.ZERO else zone.size
	zone.end_dialogue_id = _field_str(data, "end_dialogue_id")
	return zone


## The room's finish line: an ExitSign to look at plus an invisible Area2D
## trigger in the "exit" group. LdtkWorld connects to that group and slides
## the camera to the next room — see scripts/ldtk_world.gd.
func _build_exit(data: Dictionary) -> Area2D:
	print("DEB IMP: Exit data fields for ", data.get("identifier"), ": ", data.fields)
	var trigger := Area2D.new()
	trigger.name = "Exit"
	trigger.position = data.position
	trigger.collision_layer = 8  # layer 4 "triggers"
	trigger.collision_mask = 2  # player only
	trigger.add_to_group("exit", true)  # persistent so it survives packing
	trigger.set_meta("next_room", _field_str(data, "NextRoom"))

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var size := Vector2(data.size)
	var original_size := size if size != Vector2.ZERO else Vector2(16, 32)
	rect.size = original_size
	shape.shape = rect
	# Position collision shape and exit sign relative to the entity's actual pivot from LDtk.
	var pivot: Vector2 = data.get("pivot", Vector2(0.5, 1.0))
	shape.position = original_size * 0.5 - pivot * original_size

	# Extend the collision shape horizontally by 16px (8px left, 8px right)
	# so that players pressed against boundary walls still overlap with the trigger.
	rect.size.x += 16.0

	var sign: Node2D = EXIT_SIGN_SCENE.instantiate()
	sign.position = Vector2(original_size.x * (0.5 - pivot.x), -pivot.y * original_size.y - 4.0)  # hangs above the doorway
	trigger.add_child(shape)
	trigger.add_child(sign)
	return trigger


## A ceiling-mounted twin of _build_exit — same trigger, same "exit" group,
## same NextRoom meta, so it advances the room exactly like the floor Exit.
## Only the art and the anchor differ: pivot is centre like every other sized
## entity here (Exit itself is the one legacy exception, pivot 0/0), so
## `data.position` is already the box's centre and nothing needs offsetting —
## the sign is simply the whole fixture, centred on the trigger.
func _build_exit_ceiling(data: Dictionary) -> Area2D:
	var trigger := Area2D.new()
	trigger.name = "ExitCeiling"
	trigger.position = data.position
	trigger.collision_layer = 8  # layer 4 "triggers"
	trigger.collision_mask = 2  # player only
	trigger.add_to_group("exit", true)  # persistent so it survives packing
	trigger.set_meta("next_room", _field_str(data, "NextRoom"))

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var size := Vector2(data.size)
	rect.size = size if size != Vector2.ZERO else Vector2(8, 16)
	shape.shape = rect

	var sign: Node2D = EXIT_CEILING_SIGN_SCENE.instantiate()
	trigger.add_child(shape)
	trigger.add_child(sign)
	return trigger


## A climbable rail, at the height it was dragged to. `position` is the
## entity's centre, like every other sized entity here; Ladder centres its own
## box and rungs on that too.
func _build_ladder(data: Dictionary) -> Ladder:
	var ladder: Ladder = LADDER_SCENE.instantiate()
	ladder.position = data.position
	var drawn := Vector2(data.size)
	ladder.height = drawn.y if drawn.y > 0.0 else ladder.height
	return ladder


## LDtk field values come through as `null` when the field exists but hasn't
## been typed into yet (not merely absent) — Dictionary.get()'s default only
## covers a MISSING key, not a present-but-null one, so every field read
## goes through this instead of a raw .get(key, "").
func _field_str(data: Dictionary, key: String) -> String:
	var raw = data.fields.get(key)
	return raw if raw is String else ""


## An LDtk ENUM field, as its bare value. NOT _field_str, and this is the whole
## reason it exists: the importer hands an enum back QUALIFIED. Read
## `__parse_enum` in addons/ldtk-importer/src/util/field-util.gd — the regex
## there pulls the enum's NAME out of the `LocalEnum.ThoughtMotion` type string,
## and the value it returns is `"ThoughtMotion.Circle"`, never `"Circle"`.
##
## Matching the bare name against that misses EVERY value and falls through to
## whatever the default case is, which is not an error anywhere: the entity
## imports, draws, and quietly behaves as though the field were never set. That
## shipped once — every DarkThought in the world drifted vertically no matter
## what Motion said in LDtk.
##
## Splitting on the last "." accepts the bare form too, so this keeps working if
## the addon is ever fixed upstream.
func _field_enum(data: Dictionary, key: String) -> String:
	var raw = data.fields.get(key)
	if not (raw is String):
		return ""
	var text: String = raw
	var dot := text.rfind(".")
	return text.substr(dot + 1) if dot >= 0 else text


## Same null-safety as _field_str, for Int fields.
func _field_int(data: Dictionary, key: String, fallback: int) -> int:
	var raw = data.fields.get(key)
	return int(raw) if raw is int or raw is float else fallback


## Same, for Float fields. An unset LDtk field arrives as null, and a null that
## becomes 0.0 is a slide with no angle and no push — worse than the default,
## because it looks configured.
func _field_float(data: Dictionary, key: String, fallback: float) -> float:
	var raw = data.fields.get(key)
	return float(raw) if raw is float or raw is int else fallback


## Walking into this Area2D (invisible at runtime — Area2D/CollisionShape2D
## never render outside the editor; what LDtk shows as a colored box is just
## its OWN editor visualization, not something that carries into the game)
## fades Rumi in beside the trigger, same appear/say/vanish beat the
## hand-built levels use (see level1_office.gd's _rumi_appear/_rumi_vanish).
## The actual body_entered connection lives in ldtk_rumi_trigger.gd's
## _ready(), NOT here — a connection made once at this (import) time doesn't
## survive being packed into the saved .scn and reloaded.
func _build_rumi_trigger(data: Dictionary) -> Area2D:
	var trigger := Area2D.new()
	trigger.set_script(RUMI_TRIGGER_SCRIPT)
	trigger.name = "RumiTrigger"
	trigger.position = data.position
	trigger.dialogue_line = _field_str(data, "DialogueLine")
	# A full-height PILLAR, not a box on the floor: the trigger keeps its placed
	# width but is stretched to span any room top to bottom, so the beat cannot
	# be skipped by jumping or dashing over it. Rooms are 192px tall; 320 covers
	# that with room to spare wherever in the room the entity was dropped.
	const PILLAR_HEIGHT := 320.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var placed := Vector2(data.size)
	rect.size = Vector2(placed.x if placed.x > 0.0 else 16.0, PILLAR_HEIGHT)
	shape.shape = rect
	trigger.add_child(shape)

	var rumi := AnimatedSprite2D.new()
	rumi.name = "Rumi"
	rumi.sprite_frames = RUMI_FRAMES
	rumi.animation = "idle"
	rumi.autoplay = "idle"
	rumi.scale = Vector2(0.5, 0.5)
	rumi.modulate = Color(RUMI_GOLD.r, RUMI_GOLD.g, RUMI_GOLD.b, 0.0)
	trigger.add_child(rumi)

	var rumi_light := PointLight2D.new()
	rumi_light.name = "RumiLight"
	rumi_light.texture = RUMI_LIGHT_TEXTURE
	rumi_light.texture_scale = 2.8
	rumi_light.color = Color(1, 0.82, 0.45, 1)
	rumi_light.energy = 0.0
	rumi_light.position = Vector2(0, -19)
	trigger.add_child(rumi_light)

	return trigger
