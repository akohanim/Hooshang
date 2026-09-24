extends Node
var world:LdtkWorld
var player:Player
var failures:Array[String]=[]
func frames(n:int)->void:
	for i in n:await get_tree().physics_frame
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func room(name:String)->Node2D:
	for r in world.rooms:
		if r.name==name:return r
	return null
func open(name:String)->Node2D:
	world._enter_room(room(name),true)
	await frames(6)
	return room(name).get_node("DarknessRoom")
func _ready()->void:
	SaveGame.slot=-1
	LdtkWorld.debug_start_room="Level_15"
	world=load("res://ldtk/Act1World.tscn").instantiate()
	add_child(world)
	await frames(8)
	player=world.player;player.has_dash=true
	for name in ["Level_V10","Level_V11","Level_V12","Level_V13","Level_V14"]:
		var c:=await open(name)
		check(c!=null,"%s imports its authored encounter" % name)
		check(player.z_index>c.z_index,"%s player stays visible above puzzle indicators" % name)
		check(not c.solved and not c.gate_shape.disabled,"%s cannot bypass its puzzle through the exit" % name)
		check(c.bridges.all(func(b):return b.get_child(0).shape.size.y==8),"%s dynamic scaffold collision is one tile" % name)
		await frames(230)
		check(player.state!=Player.State.DEAD,"%s entry permits observation without blind damage" % name)
	print("DARKNESS CONTRACT: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
