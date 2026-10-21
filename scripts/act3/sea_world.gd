class_name SeaWorld
extends LdtkWorld
## Act III — the sea (ldtk/Act3World.tscn). Everything ordinary rooms do comes
## from LdtkWorld; what the sea adds:
##
##  - ROOMS ARE JOINED BY THEIR EDGES. An opening in one room's border that meets
##    an opening in its neighbour's is a two-way portal (the prison's system,
##    scripts/prison/prison_world.gd, rebuilt here for the sea so neither Act can
##    break the other). That is what lets the act go DOWN: most chapters end by
##    dropping through a floor. Crossing keeps his position along the seam, so a
##    fall through a wide hole lands under where he fell.
##  - WATER is the semantic grid's (SeaRoom.has_water_at), with the same
##    enter-on-centre / stay-while-overlapping hysteresis LdtkWorld's painted
##    water uses, and it REFILLS the air dash (Celeste's rule).
##  - THE SEA SWIMS DIFFERENTLY: quicker and lighter than the pond, neutral in
##    deep water (apply_sea_movement).
##  - Story state (the Dive, memories remembered, scenes played) is saved here.

## Rooms entered by a portal hold their checkpoint until he first stands or
## swims — so a respawn after a drop puts him where he landed, not mid-air.
var _settle_checkpoint := false
var portals: Array[Dictionary] = []
var _portal_armed: Dictionary = {}
var _portal_cooldown := 0.0
## Saved story flags: "scene:<name>" for beats played, plus anything a beat
## wants to remember. Read/written by Act3Beats.
var story: Dictionary = {}
var memories: Array[String] = []
const SEA_IMPORT := preload("res://scripts/act3/sea_import.gd")


func _ready() -> void:
	super._ready()
	# He has had the dash since Act I's second room, and the sea is built on it
	# (water refills it; the pier is the first place it is needed). A save or a
	# hand-off that carried no world state must not arrive without it.
	player.has_dash = true
	apply_sea_movement(player)
	# His faint presence light is for the dark acts. In a sea with no
	# CanvasModulate it only blows the water out to a white halo around him.
	var presence := player.get_node_or_null("PresenceLight") as PointLight2D
	if presence != null:
		presence.enabled = false
	_build_portals()
	for memory in get_tree().get_nodes_in_group("sea_memory"):
		var m := memory as SeaMemory
		if m.memory_id in memories:
			m.mark_done()
		m.remembered.connect(_on_memory_remembered)


## Act III's swim. Faster and more responsive than Act II's pond (which is a
## gentle crossing), because here most of the act is IN the water and precision
## underwater has to feel as good as precision on land.
static func apply_sea_movement(p: Player) -> void:
	p.swim_speed = 62.0
	p.swim_accel = 380.0
	p.swim_turn_speed = 16.0
	p.swim_max_sink_speed = 62.0
	p.swim_buoyancy = 22.0
	p.deep_buoyancy = 2.0
	p.swim_surface_pop_speed = 115.0


func sea_room(room: Node) -> SeaRoom:
	return room.get_node_or_null("SeaRoom") as SeaRoom if room != null else null


## Each Act III room is finished by an import step (scripts/act3/sea_import.gd,
## called from ldtk_level_post_import.gd) that adds its SeaRoom, its metadata and
## the sea's own entities. A Godot editor that was already open when that hook
## changed re-imports with the copy it loaded at startup, and that copy has no
## sea step. It reports nothing. The rooms come out with no water, no colour and
## no portals, and he cannot leave the first room. The raw entity data is still
## in every packed level, so the step is redone here for any room missing it.
func _prepare_rooms() -> void:
	var redone := 0
	for room in rooms:
		if not str(room.name).begins_with("Act3_") or not room is LDTKLevel:
			continue
		if sea_room(room) == null:
			SEA_IMPORT.apply(room as LDTKLevel)
			redone += 1
		else:
			# Rooms imported before the pillars were clipped (see sea_import.gd)
			# still reach into their neighbours; clipping twice changes nothing.
			SEA_IMPORT._clip_rumi_pillars(room as LDTKLevel, room.get_node("Entities"))
	if redone > 0:
		push_warning("SeaWorld: %d rooms were imported without their sea step; rebuilt at load. Restart the editor and re-import to fix the files." % redone)


# ------------------------------------------------------------------ state ---

func save_state() -> Dictionary:
	var state := super.save_state()
	state["act3"] = {
		"story": story.duplicate(),
		"memories": memories.duplicate(),
		"has_swim_dash": player != null and player.has_swim_dash,
	}
	return state


func _restore_state() -> void:
	super._restore_state()
	var state := SaveGame.state_for("world_state")
	var act3: Variant = state.get("act3", null)
	if act3 is Dictionary:
		story = (act3 as Dictionary).get("story", {}).duplicate()
		for id in (act3 as Dictionary).get("memories", []):
			memories.append(str(id))
		player.has_swim_dash = bool((act3 as Dictionary).get("has_swim_dash", false))
		return
	# No Act III state: a fresh arrival from Act II starts at the shore with
	# nothing, while a room opened cold (chapter browser, debug) gets what a
	# player reaching it would have — the Dive past Rumi's gift, and the
	# scenes before it treated as already seen.
	var start := LdtkWorld.index_in_name(debug_start_room) if debug_start_room.begins_with("Act3_") else 0
	player.has_swim_dash = start > LdtkWorld.index_in_name("Act3_Level_4")
	if start > 0:
		story["cold_open"] = true


func _on_memory_remembered(memory: SeaMemory) -> void:
	if memory.memory_id not in memories:
		memories.append(memory.memory_id)
	SaveGame.save_now()


# ----------------------------------------------------------------- rooms ----

func _add_ceiling(room: Node2D) -> void:
	# Sea rooms are closed by their own semantic border (open only at
	# apertures); a lid on top would plug every hole down into a room above.
	if not str(room.name).begins_with("Act3_"):
		super._add_ceiling(room)


## Portals are two-way already, so the return-door strip never hangs here.
func _arm_return(_from_room: Node2D) -> void:
	_clear_return()


func _enter_room(room: Node2D, snap: bool) -> void:
	super._enter_room(room, snap)
	_portal_armed.clear()
	AirBubble.reset_all(get_tree())
	InkFlood.reset_all(get_tree())
	for platform in get_tree().get_nodes_in_group("crumbling"):
		if platform is CrumblingPlatform and room.is_ancestor_of(platform):
			platform.reset()


func _on_player_died() -> void:
	_portal_armed.clear()
	await super._on_player_died()
	_portal_armed.clear()
	AirBubble.reset_all(get_tree())
	InkFlood.reset_all(get_tree())


func surface_y_at(world_pos: Vector2) -> float:
	var sea := sea_room(current_room)
	if sea != null:
		return sea.surface_y_at(world_pos)
	return super.surface_y_at(world_pos)


# --------------------------------------------------------------- portals ----

## Every run of open cells along a shared edge of two adjacent sea rooms, as a
## thin rect straddling the seam. Open = air or water on BOTH sides.
func _build_portals() -> void:
	portals.clear()
	for room in rooms:
		var a := sea_room(room)
		if a == null:
			continue
		var r := room_rect(room)
		for other in rooms:
			var b := sea_room(other)
			if other == room or b == null:
				continue
			var s := room_rect(other)
			var side := is_equal_approx(r.end.x, s.position.x) or is_equal_approx(s.end.x, r.position.x)
			var stack := is_equal_approx(r.end.y, s.position.y) or is_equal_approx(s.end.y, r.position.y)
			if not side and not stack:
				continue
			var start := maxf(r.position.y, s.position.y) if side else maxf(r.position.x, s.position.x)
			var end := minf(r.end.y, s.end.y) if side else minf(r.end.x, s.end.x)
			if end - start < 8.0:
				continue
			var direction: Vector2
			if side:
				direction = Vector2.RIGHT if is_equal_approx(r.end.x, s.position.x) else Vector2.LEFT
			else:
				direction = Vector2.DOWN if is_equal_approx(r.end.y, s.position.y) else Vector2.UP
			var seam: float
			match direction:
				Vector2.RIGHT: seam = r.end.x
				Vector2.LEFT: seam = r.position.x
				Vector2.DOWN: seam = r.end.y
				_: seam = r.position.y
			var run_start := -INF
			var coordinate := start
			while coordinate <= end:
				var open := false
				if coordinate < end:
					var point := Vector2(seam, coordinate + 4.0) if side else Vector2(coordinate + 4.0, seam)
					open = a.value_at(a.cell_at(point - direction * 4.0)) in [0, 4] \
						and b.value_at(b.cell_at(point + direction * 4.0)) in [0, 4]
				if open and run_start == -INF:
					run_start = coordinate
				if not open and run_start != -INF:
					if coordinate - run_start >= 16.0:
						var center := Vector2(seam, (run_start + coordinate) * 0.5) if side \
							else Vector2((run_start + coordinate) * 0.5, seam)
						var size := Vector2(12.0, coordinate - run_start) if side \
							else Vector2(coordinate - run_start, 12.0)
						portals.append({"from": room, "to": other, "rect": Rect2(center - size * 0.5, size),
							"direction": direction, "center": center, "seam": seam,
							"lo": run_start, "hi": coordinate})
					run_start = -INF
				coordinate += 8.0


## Where crossing `portal` at `at` lands him: just past the seam, at the same
## place along it (clamped inside the opening), nudged clear of any solid.
func portal_arrival(portal: Dictionary, at: Vector2) -> Vector2:
	var d: Vector2 = portal.direction
	var lo: float = float(portal.lo) + Player.HALF_WIDTH + 1.0
	var hi: float = float(portal.hi) - Player.HALF_WIDTH - 1.0
	var p: Vector2
	if d.y == 0.0:
		lo = float(portal.lo) + Player.HALF_HEIGHT + 1.0
		hi = float(portal.hi) - Player.HALF_HEIGHT - 1.0
		p = Vector2(float(portal.seam) + d.x * 12.0, clampf(at.y, lo, maxf(lo, hi)))
	else:
		p = Vector2(clampf(at.x, lo, maxf(lo, hi)), float(portal.seam) + d.y * (Player.HALF_HEIGHT + 8.0))
	return p


func _physics_process(delta: float) -> void:
	var sea := sea_room(current_room)
	if sea == null:
		super._physics_process(delta)
		return
	if current_room == null or _transitioning or player.state == Player.State.DEAD:
		return
	_portal_cooldown = maxf(0.0, _portal_cooldown - delta)
	if _in_thought_tile() and not player.has_thought_immunity():
		player.die()
		return
	# Water: in on the centre, stay while the body still overlaps (see
	# LdtkWorld._in_water_tile for the flicker this hysteresis prevents).
	var wet := sea.has_water_at(player.global_position)
	if player.swimming() and not wet:
		var box := player.hitbox_rect().grow(-1.0)
		for corner in [box.position, Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y),
				box.end, Vector2(box.get_center().x, box.position.y), Vector2(box.get_center().x, box.end.y)]:
			if sea.has_water_at(corner):
				wet = true
				break
	if wet:
		if not player.swimming():
			player.enter_swim(self)
		player.dash_available = true
	else:
		player.exit_swim(self)
	if _settle_checkpoint and (player.is_on_floor() or player.swimming()) and not player.input_locked:
		_settle_checkpoint = false
		_checkpoint = player.global_position
	if player.input_locked:
		return
	for portal in portals:
		if portal.from != current_room:
			continue
		var token := str((portal.to as Node).name)
		if not (portal.rect as Rect2).has_point(player.global_position):
			_portal_armed[token] = true
			continue
		if not _portal_armed.get(token, false) or _portal_cooldown > 0.0:
			continue
		_portal_cooldown = 0.5
		var arrival := portal_arrival(portal, player.global_position)
		var keep := player.velocity
		var target: Node2D = portal.to
		player.cancel_dialogue_motion()
		_cross(target, arrival, keep, portal.direction)
		return
	if player.global_position.y > room_rect(current_room).end.y + kill_margin:
		player.die()


## Frozen for the slide, as Celeste does it, then handed back exactly the
## velocity he crossed with: a jump across a seam keeps its arc, a fall keeps
## falling, a swim keeps swimming. (LdtkWorld's slide alone zeroes velocity and
## leaves physics running, which drops a mid-air crossing straight down.)
## SaveGame autosaves on the room_changed this emits.
func _cross(target: Node2D, arrival: Vector2, keep: Vector2, _direction: Vector2) -> void:
	player.freeze()
	await _slide_to_room(target, arrival)
	player.unfreeze()
	player.velocity = keep
	_settle_checkpoint = true
	_portal_armed.clear()
