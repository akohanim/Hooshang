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
const RUMI_TRIGGER_SCRIPT := preload("res://scripts/ldtk_rumi_trigger.gd")
const LDTK_DOOR_SCRIPT := preload("res://scripts/ldtk_door.gd")
const EXIT_SIGN_SCENE := preload("res://scenes/props/ExitSign.tscn")
const NOTE_TILE_SCENE := preload("res://scenes/props/NoteTile.tscn")
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
			"RumiTrigger":
				entity_layer.add_child(_build_rumi_trigger(data))
			"Exit":
				entity_layer.add_child(_build_exit(data))
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


## The room's finish line: an ExitSign to look at plus an invisible Area2D
## trigger in the "exit" group. LdtkWorld connects to that group and slides
## the camera to the next room — see scripts/ldtk_world.gd.
func _build_exit(data: Dictionary) -> Area2D:
	var trigger := Area2D.new()
	trigger.name = "Exit"
	trigger.position = data.position
	trigger.collision_layer = 0
	trigger.collision_mask = 2  # player only
	trigger.add_to_group("exit", true)  # persistent so it survives packing
	trigger.set_meta("next_room", _field_str(data, "NextRoom"))

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var size := Vector2(data.size)
	rect.size = size if size != Vector2.ZERO else Vector2(16, 32)
	shape.shape = rect
	# Entity pivot is bottom-centre, so lift the box to sit on that point.
	shape.position = Vector2(0, -rect.size.y * 0.5)
	trigger.add_child(shape)

	var sign: Node2D = EXIT_SIGN_SCENE.instantiate()
	sign.position = Vector2(0, -rect.size.y - 4.0)  # hangs above the doorway
	trigger.add_child(sign)
	return trigger


## LDtk field values come through as `null` when the field exists but hasn't
## been typed into yet (not merely absent) — Dictionary.get()'s default only
## covers a MISSING key, not a present-but-null one, so every field read
## goes through this instead of a raw .get(key, "").
func _field_str(data: Dictionary, key: String) -> String:
	var raw = data.fields.get(key)
	return raw if raw is String else ""


## Same null-safety as _field_str, for Int fields.
func _field_int(data: Dictionary, key: String, fallback: int) -> int:
	var raw = data.fields.get(key)
	return int(raw) if raw is int or raw is float else fallback


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
