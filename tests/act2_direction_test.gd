extends "res://tests/act2_direction_preview.gd"
## Same full playback as the rendered review, with body/portrait assertions.
## Run once per --mode=pond|wall|keys|rescue|banter|reunion|ending.
var failures: Array[String] = []
var pages := 0
var saw_adult_grip := false
var saw_child_grip := false
var bank_faces := {}
var spoken: Array[String] = []
const TEXT := preload("res://resources/dialogue/act2_author_script.tres")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func capture(stem: String) -> void:
	var player := world.player
	var needs_floor := true
	if mode=="pond": needs_floor=Dialogue._active and not player.swimming()
	if mode=="ending":
		needs_floor=player.visible and player.visual.animation!=&"swim_idle" and player.visual.animation!=&"swim"
	if needs_floor:
		var feet := Vector2(player.global_position.x,player.hitbox_rect().end.y)
		check(supported(feet),mode+"/"+stem+": held body has physical ground at its feet")
	if not Dialogue._active:
		if mode=="rescue":
			var actor: Node2D=world.get_node("CellReunion").actor
			check(supported(actor.global_position),"rescued Jamshid waits on actual support, not the doorway well")
		return
	pages+=1
	spoken.append(Dialogue._page_raw)
	if mode in ["keys","rescue"]:
		check(not world._hud.visible,"quest HUD clears the conversation composition")
		for prop in world.props:
			if prop.kind=="PrisonSign" and world.current_room.is_ancestor_of(prop):
				check(not prop.visible,"navigation labels do not draw over the conversation actors")
	if mode=="ending":
		var ending=world.get_node("Act2Ending")
		var memory=ending.get_node("Cinema/Stage/Memory")
		var child: AnimatedSprite2D=ending.get_node("Cinema/Stage/Flight/Child")
		if child.is_visible_in_tree() and not memory.visible:
			saw_adult_grip=saw_adult_grip or child.sprite_frames==ending.ADULT_FAREWELL
			saw_child_grip=saw_child_grip or child.sprite_frames==ending.FAREWELL
		if ending.chapter=="second_line":
			var is_player: bool=Dialogue.name_label.text=="Hooshang"
			var left: bool=(player.global_position.x < ending.get_node("Rumi").global_position.x)==is_player
			check((Dialogue.name_label.horizontal_alignment==HORIZONTAL_ALIGNMENT_LEFT)==left,"pond portrait matches speaker's actual side")
			bank_faces[Dialogue.portrait.texture.resource_path]=true
	if mode in ["wall","rescue","banter","reunion","keys"]:
		check(player.visual.animation in [&"idle",&"sit"],"dialogue does not keep a moving pose")

func supported(feet: Vector2) -> bool:
	var query:=PhysicsRayQueryParameters2D.create(feet-Vector2(0,0.5),feet+Vector2(0,1.1),1,[world.player.get_rid()])
	return not world.player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func finish(success: bool) -> void:
	check(success,"scene reaches its playable/completed endpoint")
	check(pages>0,"scene actually spoke dialogue")
	var chapters: Array={"pond":["pond","campfire","dawn"],"wall":["wall","palace"],"keys":["keys"],"rescue":["cell"],"banter":["chase"],"reunion":["chase"],"ending":["carpet","fall","bank","second_line"]}.get(mode,[])
	var expected: Array[String]=[]
	for part in chapters:
		for i in TEXT.scenes[part].size():
			if part=="chase":
				var at_wall: int=TEXT.cue("chase","We never finished it.")
				if (mode=="banter" and i>=at_wall) or (mode=="reunion" and i<at_wall): continue
			for page in Dialogue._paginate(TEXT.scenes[part][i].text): expected.append(page)
	check(spoken==expected,"every author page plays once, in order, with unchanged words")
	if mode=="ending":
		check(saw_child_grip and saw_adult_grip,"dream breaks from child to adult grip before release")
		check(bank_faces.size()>=8,"waking conversation uses varied authored adult/Rumi expressions")
		var defaults=load("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
		for property in ["wall_jump_speed_x","wall_jump_drag"]:
			check(world.player.get(property)==defaults.get(property),"waking restores adult "+property)
		defaults.free()
	print("ACT2 DIRECTION ",mode,": ",pages," pages, ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
