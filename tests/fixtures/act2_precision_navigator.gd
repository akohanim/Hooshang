extends "res://tests/prison_navigation_test.gd"
## The older navigator hardcodes the cage's former height. Read its real box.
func clear_at(p: Vector2) -> bool:
	for dx in [-Player.HALF_WIDTH+0.01,Player.HALF_WIDTH-0.01]:
		for dy in [-Player.HALF_HEIGHT+0.01,Player.HALF_HEIGHT-0.01]:
			if geo.value_at(Vector2i(floori((p.x+dx)/8),floori((p.y+dy)/8))) in [1,3]:return false
	for prop in world.props:
		if prop.kind!="Cage" or prop.barrier.disabled or prop.get_parent().get_parent()!=world.current_room:continue
		var half:Vector2=prop.barrier.shape.size*0.5
		var rect:=Rect2(prop.barrier.global_position-world.current_room.global_position-half,half*2)
		if rect.intersects(Rect2(p-Vector2(4.5,6),Vector2(9,12))):return false
	return true
