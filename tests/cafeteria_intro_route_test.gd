extends "res://tests/prison_navigation_test.gd"
## Native input-driven first lever room. Includes expiry before a clean attempt.
const OUT := "res://output/prison_challenge/cafeteria_intro"
var activation_tick := 0
var bank_tick := -1
func _ready() -> void:
	SaveGame.unbind()
	world=load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room="Prison_R01"
	var actor=world.player_scene.instantiate()
	actor.set_script(load("res://tests/fixtures/prison_no_assist_player.gd"))
	var packed:=PackedScene.new()
	packed.pack(actor)
	actor.free()
	world.player_scene=packed
	Screen.set_scene(world)
	world.player.died.connect(func(): deaths+=1)
	world.timers.changed.connect(func():
		if bank_tick<0 and world.timers.solved("cafeteria_intro"): bank_tick=ticks)
	await frames(20)
	await run_route()
	release()
	var result:={"failure":failure,"deaths":deaths,"forbidden":forbidden,"room":str(world.current_room.name),"bank_seconds":(bank_tick-activation_tick)/60.0 if bank_tick>=0 else -1.0,"completed":world.timers.save_completed(),"trace":trace}
	FileAccess.open(OUT+"/route.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CAFETERIA INTRO INPUT ROUTE: ",JSON.stringify({"failure":failure,"deaths":deaths,"forbidden":forbidden,"bank_seconds":result.bank_seconds}))
	await shutdown(0 if failure=="" and deaths==0 and not forbidden else 1)

func run_route() -> void:
	if not await navigate(Vector2(264,154)): return
	await capture("01_lever_closed")
	var duration: float=world.props.filter(func(p): return p.kind=="TimedGate")[0].fields.Duration
	Input.action_press("move_up")
	await frames(90)
	if world.timers.remaining("cafeteria_intro")>duration-1.0 or not world.timers.active("cafeteria_intro"):
		failure="held Up refreshed timer or lever failed"; return
	Input.action_release("move_up")
	await frames(ceili(duration*60))
	if world.timers.active("cafeteria_intro"):
		failure="timer failed to expire";return
	await capture("02_safe_expiry")
	activation_tick=ticks
	Input.action_press("move_up")
	await frames(2)
	Input.action_release("move_up")
	await capture("03_gate_open")
	if not await navigate(Vector2(64,154)): return
	await frames(5)
	if not world.timers.solved("cafeteria_intro"):
		failure="relay not reached before expiry";return
	await capture("04_relay_banked")
	if not await cross("Prison_R02"): return
	if not world.timers.solved("cafeteria_intro"):
		failure="room change lost banked timer";return
	await capture("05_next_room")

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	Screen.viewport.get_texture().get_image().save_png(OUT+"/"+label+".png")
