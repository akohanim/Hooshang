extends RefCounted
## Fine brass calibration marks make a thought's orbit legible from a safe ledge.
## They are background ink, not platforms or an additional hazard.
static func draw_paths(canvas:Node2D,patterns:Array)->void:
	for path:Dictionary in patterns:
		var centre:=Vector2(path.x,path.y)
		var amplitude:float=path.amplitude
		if amplitude<=0:continue
		var circular:bool=path.motion=="Circle"
		var direction:=Vector2.DOWN
		if path.motion=="Horizontal":direction=Vector2.RIGHT
		elif path.motion=="Linear":direction=Vector2.from_angle(deg_to_rad(path.angle))
		for i in range(24 if circular else 13):
			var p:=centre
			if circular:p+=Vector2.from_angle(TAU*i/24.0)*amplitude
			else:p+=direction*lerpf(-amplitude,amplitude,i/12.0)
			canvas.draw_rect(Rect2(p.round(),Vector2.ONE),Color(0.7,0.59,0.48,0.45))
