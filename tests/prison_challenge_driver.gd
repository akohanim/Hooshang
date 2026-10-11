extends Node
## Reuse earned wing recipes in one existing world; never inject progress/positions.
var world: Node
var failure := ""
var deaths := 0
var forbidden := false
var reports: Array = []
var capture_root := "res://output/prison_challenge/integration/mission"
const ROUTES := {"Green":"precision_library_connected_test", "Red":"precision_cafeteria_connected_test", "Blue":"basement_capstone_route_test", "Gold":"precision_gym_music_test"}
func traverse(order: Array) -> bool:
	for color in order:
		var driver=load("res://tests/"+ROUTES[color]+".gd").new()
		driver.run_on_ready=false
		driver.world=world
		var wing_out=capture_root+"/"+color
		if color!="Red":driver.capture_root=wing_out
		DirAccess.make_dir_recursive_absolute(wing_out)
		if color in ["Blue","Gold"]:
			driver.full_loop=true
			driver.skip_patrol_wait=true
		add_child(driver)
		var on_death=func():driver.deaths+=1
		world.player.died.connect(on_death)
		if color in ["Green","Red"]:await driver.run_loop()
		else:await driver.run_route()
		driver.release()
		world.player.died.disconnect(on_death)
		deaths+=driver.deaths
		forbidden=forbidden or driver.forbidden
		var result={"wing":color,"failure":driver.failure,"deaths":driver.deaths,"forbidden":driver.forbidden,"trace":driver.trace}
		reports.append(result)
		FileAccess.open(wing_out+"/route.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
		if driver.failure!="" or driver.deaths>0 or driver.forbidden or not world.collected.has(color):
			failure=color+": "+driver.failure
		driver.queue_free()
		await get_tree().physics_frame
		if failure!="":return false
		print("CONNECTED WING PASS ",color," keys=",world.collected)
	return true
