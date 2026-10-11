extends LdtkWorld
## Act 2's prison mission. Ordinary Act 2 rooms retain LdtkWorld's routing.
signal prison_completed
const IDS := ["Red", "Green", "Blue", "Gold"]
const PuzzleSave := preload("res://scripts/prison/prison_save_migration.gd")
var collected: Array[String] = []
var inserted: Array[String] = []
var story_flags: Dictionary = {}
var circuits = preload("res://scenes/props/prison/circuits/circuit_state.gd").new()
var timers = preload("res://scenes/props/prison/timed/timed_state.gd").new()
var rescued := false
var rescue_started := false
var portals: Array[Dictionary] = []
var props: Array[Node] = []
var _portal_cooldown := 0.0
var _portal_armed: Dictionary = {}
var _hud: Label
var _shortcut_hint: Label
var _rescue_tween: Tween
var _cage: Node2D

func _ready() -> void:
	super._ready()
	for room in rooms:
		if not is_prison(room): continue
		for prop in room.get_node("Entities").get_children():
			if prop.has_method("bind"):
				props.append(prop)
				if prop.kind == "Cage": _cage = prop
	for prop in props: prop.bind(self)
	_build_portals()
	for room in rooms:
		if is_prison(room): room.get_node("PrisonGeometry").world = self
	var layer := preload("res://scenes/props/prison/PrisonHUD.tscn").instantiate()
	layer.custom_viewport = get_tree().root
	add_child(layer)
	_hud = layer.get_node("Keys")
	_shortcut_hint = layer.get_node("Shortcut")
	_refresh()
	var state: Dictionary = SaveGame.state_for("world_state").get("prison",{})
	if is_prison(current_room) and state.get("checkpoint_mode", "") == "room_entry" and state.get("checkpoint_room", "") == str(current_room.name):
		var point: Array = state.get("checkpoint",[])
		if point.size() == 2:
			var saved := Vector2(float(point[0]),float(point[1]))
			if room_rect(current_room).has_point(saved):
				_checkpoint = _safe_landing(current_room,saved)
				player.global_position = _checkpoint
	if rescued: _position_rescued_actor()

func is_prison(room: Node) -> bool:
	return room != null and str(room.name).begins_with("Prison_")

func _add_ceiling(room: Node2D) -> void:
	if not is_prison(room): super._add_ceiling(room)
	# Prison Collision has closed boundaries except authored paired apertures.

func _room_before(room: Node2D) -> Node2D:
	if room != null and room.name == "Act_2_Level_16":
		for candidate in rooms:
			if candidate.name == "Prison_Hub": return candidate
	return super._room_before(room)

func _arm_return(from_room: Node2D) -> void:
	if is_prison(current_room) or (current_room != null and current_room.name == "Act_2_Level_20"):
		_clear_return()
		return
	super._arm_return(from_room)

func _enter_room(room: Node2D, snap: bool) -> void:
	circuits.reset_attempts()
	timers.reset_attempts()
	super._enter_room(room,snap)
	if is_prison(room):
		_portal_armed.clear()
		# Untimed musical routes use the existing crumble stones. Revisiting
		# their room must restore the route even without a linked lever.
		for entity in room.get_node("Entities").get_children():
			if entity is CrumblingPlatform: entity.reset()
		_clear_return()
		player.has_dash = true
		for prop in props:
			if prop.kind == "Patrol": prop.clock = 0.0
	_refresh()

func _restore_state() -> void:
	super._restore_state()
	story_flags = SaveGame.state_for("world_state").get("act2_story", {}).duplicate()
	var raw: Variant = SaveGame.state_for("world_state").get("prison",{})
	if not raw is Dictionary: return
	raw = PuzzleSave.upgrade(raw, str(SaveGame.state_for("world_state").get("room", "")))
	circuits.restore(raw.get("completed_circuits", []))
	timers.restore(raw.get("completed_timers", []))
	for id in raw.get("collected",[]):
		if id in IDS and not collected.has(id): collected.append(id)
	for id in raw.get("inserted",[]):
		if collected.has(id) and not inserted.has(id): inserted.append(id)
	rescued = bool(raw.get("rescued",false)) and inserted.size() == 4
	rescue_started = rescued

func save_state() -> Dictionary:
	var state := super.save_state()
	state["act2_story"] = story_flags.duplicate()
	state["prison"] = {"collected":collected.duplicate(),"inserted":inserted.duplicate(),"rescued":rescued,
		"puzzle_revision":PuzzleSave.REVISION,
		"completed_circuits":circuits.save_completed(),
		"completed_timers":timers.save_completed(),
		"checkpoint_mode":"room_entry", "checkpoint_room":str(current_room.name) if current_room != null else "",
		"checkpoint":[_checkpoint.x,_checkpoint.y]}
	return state

func circuit_reference(reference: Variant) -> Node2D:
	var ref := str(reference)
	for prop in props:
		if prop.kind in ["CircuitGate", "FloodGate", "MusicalGate"] and (prop.entity_iid == ref or str(prop.get_path()) == ref):
			return prop
	return null

func timed_reference(reference: Variant) -> Node2D:
	var ref := str(reference)
	for prop in props:
		if prop.kind == "TimedGate" and (prop.entity_iid == ref or str(prop.get_path()) == ref): return prop
	return null

func key_for_reference(reference: Variant) -> String:
	var ref := str(reference)
	for prop in props:
		if prop.kind == "Key" and (prop.entity_iid == ref or str(prop.get_path()) == ref): return prop.key_id
	return ""

func collect_key(id: String, _at: Vector2) -> void:
	if not IDS.has(id) or collected.has(id): return
	collected.append(id)
	$Act2Audio.play_cue(&"Key")
	_refresh()
	SaveGame.save_now()

func _refresh() -> void:
	for prop in props: prop.refresh()
	for room in rooms:
		if is_prison(room): room.get_node("PrisonGeometry").queue_redraw()
	if _hud == null: return
	_hud.visible = is_prison(current_room)
	var text := ""
	for id in IDS:
		text += ("✓" if inserted.has(id) else "●" if collected.has(id) else "○") + id + "  "
	_hud.text = "JAMSHID FREE — FOLLOW HIM TO THE COURTYARD" if rescued else text + "  %d/4 locks" % inserted.size()
	_update_shortcut_hint()
	_layout_prison_hud()

func _layout_prison_hud() -> void:
	# Keep the status in a stable corner opposite a wing's upper doorway.
	# Do not follow the player: moving labels would distract during jumps.
	var right := false
	if is_prison(current_room) and current_room.size.x == Screen.GAME_SIZE.x:
		for portal in portals:
			if portal.from == current_room and portal.direction == Vector2.UP:
				right = portal.center.x - current_room.global_position.x < Screen.GAME_SIZE.x * 0.5
				break
	for label in [_hud, _shortcut_hint]:
		label.reset_size()
		label.position.x = Screen.GAME_SIZE.x * 4 - 24 - label.size.x if right else 24

func _update_shortcut_hint() -> void:
	if _shortcut_hint == null: return
	_shortcut_hint.hide()
	if not is_prison(current_room) or _transitioning or player.input_locked or player.state == Player.State.DEAD: return
	var nearest := 80.0
	var needed := ""
	for portal in portals:
		if portal.from != current_room or portal.gate == "" or collected.has(portal.gate): continue
		var distance: float = player.global_position.distance_to(portal.center)
		if distance < nearest:
			nearest = distance
			needed = portal.gate
	if needed != "":
		_shortcut_hint.text = needed.to_upper() + " KEY OPENS THIS SHORTCUT"
		_shortcut_hint.show()
	_layout_prison_hud()

func insert_keys(cage: Node2D) -> void:
	if rescue_started or player.state == Player.State.DEAD: return
	# Serialization guard also covers a second contact during the lock animation.
	rescue_started = true
	if collected.size() == 4:
		player.input_locked = true
		player.velocity = Vector2.ZERO
	for id in cage.lock_ids():
		if collected.has(id) and not inserted.has(id):
			inserted.append(id)
			$Act2Audio.play_cue(&"Lock")
			_refresh()
			await get_tree().create_timer(0.2,false).timeout
	if inserted.size() < 4:
		rescue_started = false
		SaveGame.save_now()
		return
	player.input_locked = true
	player.velocity = Vector2.ZERO
	cage.sprite.texture = preload("res://ldtk/art/prison/cage_open.png")
	$Act2Audio.play_cue(&"Gate")
	cage.barrier.set_deferred("disabled",true)
	var actor := cage.get_parent().get_node_or_null("PrisonJamshid") as Jamshid
	if actor != null:
		actor.play_pose("walk")
		actor.face_left(false)
		_rescue_tween = create_tween()
		_rescue_tween.tween_interval(0.5)
		_rescue_tween.tween_property(actor,"position:x",cage.position.x+58,1.5)
		await _rescue_tween.finished
	finish_rescue()

func finish_rescue() -> void:
	if rescued or inserted.size() != 4: return
	rescued = true
	rescue_started = true
	_position_rescued_actor()
	player.input_locked = false
	_refresh()
	# The cell reunion, chase and farewell still follow this milestone.
	SaveGame.save_now()
	prison_completed.emit()

func _position_rescued_actor() -> void:
	if _cage == null: return
	var actor := _cage.get_parent().get_node_or_null("PrisonJamshid") as Jamshid
	if actor != null:
		actor.position.x = _cage.position.x+58
		actor.play_pose("idle")

func _unhandled_input(event: InputEvent) -> void:
	if rescue_started and inserted.size() == 4 and not rescued and event.is_action_pressed("jump"):
		if _rescue_tween != null: _rescue_tween.kill()
		finish_rescue()
		return
	super._unhandled_input(event)

func _safe_landing(room: Node2D, preferred: Vector2) -> Vector2:
	var geo: Node = room.get_node("PrisonGeometry")
	var best := Vector2.INF
	var distance := INF
	for cell: Vector2i in geo.grid.get_used_cells():
		if geo.value_at(cell) not in [1,2]: continue
		var candidate: Vector2 = geo.grid.to_global(Vector2(cell*8)+Vector2(4,-6.1))
		var clear := true
		for dx in [-1,0,1]:
			for dy in [-1,-2]:
				if geo.value_at(cell+Vector2i(dx,dy)) in [1,3]: clear = false
		if not clear or not room_rect(room).encloses(Rect2(candidate-Vector2(4.5,6),Vector2(9,12))): continue
		var score := candidate.distance_squared_to(preferred)
		if score < distance: best = candidate; distance = score
	return spawn_point_for(room) if best == Vector2.INF else best

func _build_portals() -> void:
	portals.clear()
	for room in rooms:
		if not is_prison(room): continue
		var r := room_rect(room)
		var geo: Node = room.get_node("PrisonGeometry")
		for other in rooms:
			if room == other or not is_prison(other): continue
			var s := room_rect(other)
			var vertical := is_equal_approx(r.end.x,s.position.x) or is_equal_approx(s.end.x,r.position.x)
			var horizontal := is_equal_approx(r.end.y,s.position.y) or is_equal_approx(s.end.y,r.position.y)
			if not vertical and not horizontal: continue
			var start := maxf(r.position.y,s.position.y) if vertical else maxf(r.position.x,s.position.x)
			var end := minf(r.end.y,s.end.y) if vertical else minf(r.end.x,s.end.x)
			var direction := Vector2.RIGHT if is_equal_approx(r.end.x,s.position.x) else Vector2.LEFT
			if not vertical: direction = Vector2.DOWN if is_equal_approx(r.end.y,s.position.y) else Vector2.UP
			var seam := r.end.x if direction == Vector2.RIGHT else r.position.x if vertical else r.end.y if direction == Vector2.DOWN else r.position.y
			var run_start := -INF
			for coordinate in range(int(start),int(end)+8,8):
				var point := Vector2(seam,float(coordinate)+4) if vertical else Vector2(float(coordinate)+4,seam)
				var other_geo: Node = other.get_node("PrisonGeometry")
				var a: Vector2i = geo.grid.local_to_map(geo.grid.to_local(point-direction*4))
				var b: Vector2i = other_geo.grid.local_to_map(other_geo.grid.to_local(point+direction*4))
				var open: bool = coordinate < end and geo.value_at(a) in [0,4] and other_geo.value_at(b) in [0,4]
				if open and run_start == -INF: run_start = coordinate
				if not open and run_start != -INF:
					if coordinate-run_start >= 24:
						var center := Vector2(seam,(run_start+coordinate)*0.5) if vertical else Vector2((run_start+coordinate)*0.5,seam)
						var size := Vector2(12,coordinate-run_start) if vertical else Vector2(coordinate-run_start,12)
						var gate := ""
						for prop in props:
							if prop.kind == "ShortcutDoor" and prop.global_position.distance_to(center) < 32: gate = prop.key_id
						portals.append({"from":room,"to":other,"rect":Rect2(center-size*0.5,size),"direction":direction,"gate":gate,"center":center})
					run_start = -INF

func _physics_process(delta: float) -> void:
	_update_shortcut_hint()
	if not is_prison(current_room):
		super._physics_process(delta)
		return
	if _transitioning or player.state == Player.State.DEAD or player.input_locked: return
	timers.tick(delta)
	_portal_cooldown = maxf(0,_portal_cooldown-delta)
	var geo: Node = current_room.get_node("PrisonGeometry")
	if geo.hazard_overlaps(player.hitbox_rect()):
		player.die()
		return
	var wet: bool = geo.has_water_at(player.global_position)
	if player.swimming():
		var box := player.hitbox_rect().grow(-1)
		wet = wet or geo.has_water_at(box.position) or geo.has_water_at(box.end)
	if wet:
		if not player.swimming(): player.enter_swim(self)
	else: player.exit_swim(self)
	for portal in portals:
		if portal.from != current_room: continue
		var token := str(portal.to.name)
		if not portal.rect.has_point(player.global_position):
			_portal_armed[token] = true
			continue
		if not _portal_armed.get(token,false): continue
		if portal.gate != "" and not collected.has(portal.gate): continue
		if _portal_cooldown > 0: continue
		var target: Node2D = portal.to
		var arrival := _safe_landing(target,portal.center+portal.direction*24)
		_portal_cooldown = 0.7
		player.exit_swim(self)
		player.cancel_dialogue_motion()
		_slide_to_room(target,arrival)
		return
	if player.global_position.y > room_rect(current_room).end.y+kill_margin: player.die()

func surface_y_at(point: Vector2) -> float:
	if is_prison(current_room): return current_room.get_node("PrisonGeometry").surface_y_at(point)
	return super.surface_y_at(point)

func _on_player_died() -> void:
	circuits.reset_attempts()
	timers.reset_attempts()
	_portal_armed.clear()
	await super._on_player_died()
	_portal_armed.clear()
	for prop in props:
		if prop.kind == "Patrol": prop.clock = 0.0
