extends Node2D
var failures:=0
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _ready()->void:
	var wall:=StaticBody2D.new()
	wall.position=Vector2(700,80)
	var shape:=CollisionShape2D.new()
	shape.shape=RectangleShape2D.new();shape.shape.size=Vector2(8,160)
	wall.add_child(shape);add_child(wall)
	await get_tree().physics_frame
	for trial in [[110.0,1.0],[10000.0,1.0],[110.0,-1.0],[10000.0,-1.0]]:
		var speed:float=trial[0]
		var direction:float=trial[1]
		wall.position.x=700 if direction>0 else 300
		await get_tree().physics_frame
		var cloud:=preload("res://scenes/props/darkness/DarkshangCloud.tscn").instantiate()
		cloud.position=Vector2(30 if direction>0 else 970,80);cloud.direction=direction;cloud.speed=speed;cloud.room_bounds=Rect2(0,0,1000,180)
		add_child(cloud);cloud.set_physics_process(false)
		for i in 1000:
			cloud._physics_process(1.0/60)
			if cloud.stopped:break
		check(cloud.stopped,"shot stops on solid geometry at speed %s" % speed)
		check(cloud.distance_travelled>650,"shot travels beyond the former timed range")
		check(absf(cloud.position.x-(688 if direction>0 else 312))<3,"full hitbox stops before the wall without tunneling")
	print("DARKSHANG CLOUD: %d failures" % failures)
	get_tree().quit(failures)
