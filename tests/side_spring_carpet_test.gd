extends Node
var failures := 0
const SPRING := preload("res://scenes/props/platforms/SpringPlatform.tscn")
const CARPET := preload("res://scenes/props/zones/MagicCarpet.tscn")
const PLAYER := preload("res://scenes/characters/hooshang/Hooshang.tscn")
var player: Player
func _ready() -> void:
	player=PLAYER.instantiate()
	add_child(player)
	player.input_locked=true
	for direction in [-1,1]:
		var spring: SpringPlatform=SPRING.instantiate()
		spring.position=Vector2(300,200)
		spring.rotation_degrees=90.0*direction
		add_child(spring)
		await frames(3)
		player.respawn(spring.global_position+Vector2(direction*14,-2))
		player.input_locked=true
		player.velocity=Vector2(-direction*120,0)
		var launched:=false
		var start:=Vector2.ZERO
		for i in 20:
			await frames(1)
			if player.velocity.x*direction>200:
				launched=true;start=player.global_position;break
		check(launched,"90-degree spring launches "+str(direction)+" through real collision")
		check(absf(player.velocity.y)<40,"side impulse is horizontal")
		await frames(15)
		check((player.global_position.x-start.x)*direction>35,"horizontal momentum survives the movement controller")
		player.respawn(Vector2(0,-100))
		spring.queue_free()
		await frames(3)
	for pattern in [0,1,2,3]:
		var carpet: MagicCarpet=CARPET.instantiate()
		carpet.position=Vector2(200,200)
		carpet.carpet_color=pattern
		carpet.speed=20
		add_child(carpet)
		player.respawn(Vector2(0,0))
		await frames(90)
		check(carpet.position==carpet._origin and not carpet.activated,"pattern %d waits indefinitely before boarding" % pattern)
		# Side and underside overlaps must not count as boarding.
		player.respawn(carpet.global_position+Vector2(19,0))
		await frames(2)
		check(not carpet.activated,"side brush does not start carpet")
		player.respawn(carpet.global_position+Vector2(0,-24))
		await frames(30)
		check(carpet.activated,"top landing starts pattern "+str(pattern))
		check(carpet.position.distance_to(carpet._origin)>1,"boarded carpet moves")
		player.respawn(Vector2(0,0))
		carpet.reset()
		await frames(15)
		check(not carpet.activated and carpet.position==carpet._origin,"reset returns carpet to parked state")
		carpet.queue_free()
		await frames(3)
	print("SIDE_SPRING_CARPET: ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)
func frames(n:int) -> void:
	for i in n:await get_tree().physics_frame
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
