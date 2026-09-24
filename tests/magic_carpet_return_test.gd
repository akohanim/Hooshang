extends Node
var failures:=0
var player:Player
var carpet:MagicCarpet
func _ready() -> void:
	var floor:=StaticBody2D.new()
	var shape:=CollisionShape2D.new()
	var box:=RectangleShape2D.new()
	box.size=Vector2(3000,16)
	shape.shape=box;floor.position=Vector2(500,228)
	floor.add_child(shape);add_child(floor)
	carpet=preload("res://scenes/props/zones/MagicCarpet.tscn").instantiate()
	carpet.position=Vector2(200,100);carpet.size=Vector2(48,8);carpet.speed=32
	add_child(carpet)
	player=preload("res://scenes/characters/hooshang/Hooshang.tscn").instantiate()
	add_child(player);player.respawn(Vector2(0,214))
	await frames(330)
	check(not carpet.activated and carpet.position==carpet._origin,"unboarded rug stays parked beyond five seconds")
	await board()
	await frames(330)
	check(carpet.activated and carpet.carrying(player),"riding for longer than five seconds never resets the rug")
	Input.action_press("jump")
	var left:=false
	for i in 10:
		await frames(1)
		if carpet._return_left>0:left=true;break
	check(left and not player.is_on_floor(),"a real jump starts the return countdown")
	var departure:=carpet.position
	var elapsed:=0
	Input.action_press("move_left")
	var steady:=true
	while carpet.activated and elapsed<310:
		var before:=carpet.position.x
		await frames(1);elapsed+=1
		if elapsed==30:
			Input.action_release("move_left")
			Input.action_release("jump")
		if carpet.activated:steady=steady and absf(carpet.position.x-before-32.0/60.0)<0.01
		if elapsed==150:
			check(player.is_on_floor(),"player reaches the recovery floor during the countdown")
			check(carpet.activated and carpet.position.x>departure.x+75,"landing on ground does not return the rug early")
	check(steady,"empty rug keeps its steady rightward flight")
	check(elapsed>=297 and elapsed<=301,"return happens five seconds after departure (%d frames)" % elapsed)
	check(not carpet.activated and carpet.position==carpet._origin,"return restores the original parked position")
	await frames(60)
	check(not carpet.activated,"returned rug waits for another landing")
	await board()
	Input.action_press("jump")
	await frames(4);Input.action_release("jump")
	player.respawn(Vector2(0,214))
	await frames(240)
	check(carpet.activated and carpet._return_left>0,"return remains pending after four seconds")
	# Catch it again before expiry; the original countdown must not strand us.
	player.respawn(carpet.global_position-Vector2(0,10))
	await frames(8)
	check(carpet.carrying(player) and carpet._return_left<0,"boarding again cancels the pending return")
	await frames(100)
	check(carpet.activated and carpet.carrying(player),"old deadline cannot reset a reboarded carpet")
	player.respawn(Vector2(0,214));await frames(8)
	check(carpet._return_left>0,"walking or falling off also starts a fresh return")
	carpet.reset();await frames(330)
	check(not carpet.activated and carpet._return_left<0 and carpet.position==carpet._origin,"room/death reset clears any pending return")
	print("MAGIC_CARPET_RETURN: ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)
func board() -> void:
	player.respawn(carpet.global_position-Vector2(0,10))
	player.input_locked=false
	await frames(8)
	check(carpet.activated and carpet.carrying(player),"landing boards the carpet")
func frames(n:int) -> void:
	for i in n:await get_tree().physics_frame
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
