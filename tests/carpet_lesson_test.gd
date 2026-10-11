extends Node
## Continuous real-input routes from the room entrance. No positional writes.
var failures: Array[String] = []
var deaths := 0
var world: LdtkWorld
var flight_frames := 0
var swam := false
var used_climb := false
var low_passage := false
var high_terrace := false
var carpet: MagicCarpet
var origin := Vector2.ZERO

func _ready() -> void:
	SaveGame.slot = -1
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/carpet_lesson_routes.json"))
	for name: String in routes:
		deaths=0;flight_frames=0;swam=false;used_climb=false;low_passage=false;high_terrace=false
		LdtkWorld.debug_start_room = "Level_2"
		world = load("res://ldtk/Act2World.tscn").instantiate()
		Screen.set_scene(world)
		await frames(30)
		origin=world.current_room.global_position
		for entity in world.current_room.get_node("Entities").get_children():
			if entity is MagicCarpet: carpet=entity
		world.player.died.connect(func(): deaths+=1)
		# Prove the lesson does not depend on land ledge assistance.
		world.player._ledge_cooldown=3600
		for step: Dictionary in routes[name]:
			for action: String in step.get("press",[]): Input.action_press(action)
			for action: String in step.get("release",[]): Input.action_release(action)
			for i in int(step.frames):
				await get_tree().physics_frame
				var at: Vector2=world.player.global_position-origin
				var riding: bool=carpet.carrying(world.player)
				if riding: flight_frames+=1
				low_passage=low_passage or (riding and at.x>440 and at.x<504 and at.y>238)
				high_terrace=high_terrace or (riding and at.x>736 and at.y<208)
				swam=swam or world.player.state==Player.State.SWIM
				used_climb=used_climb or world.player.state in [Player.State.CLIMB,Player.State.LEDGE_MANTLE]
		check(deaths==0,name+": no deaths")
		check(not used_climb,name+": no climbing or land mantle")
		check(not world.player.input_locked,name+": control remains available")
		if name=="flight":
			check(str(world.current_room.name)=="Act_2_Level_3","flight uses actual exit into gardens")
			check(flight_frames>300 and low_passage and high_terrace,"carpet carries through both steering challenges")
		else:
			var at: Vector2=world.player.global_position-origin
			check(swam and world.player.is_on_floor(),name+": exits water onto supported ground")
			check((at.x<272) if name=="left_recovery" else (str(world.current_room.name)=="Act_2_Level_3"),name+": reaches dock or onward exit")
		world.queue_free()
		await frames(3)
	print("CARPET LESSON: ","ALL PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
func frames(count:int)->void:
	for i in count: await get_tree().physics_frame
func check(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
