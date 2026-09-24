extends Node2D
## Finite room paintings cover the base sky and its sun, so the disc cannot
## obscure their architecture. Camera position drives
## the dissolve, so forward travel and backtracking produce the same framing.
## Images are set-piece art: filtered like the existing watercolor panorama.
@export var room_names: PackedStringArray = []
@export var paintings: Array[Texture2D] = []
## Small overscan keeps the painting full-bleed without cropping its crown.
@export var painting_height := 1.05
## The dissolve spans the camera's entire 320px doorway travel.
@export var transition_width := 320.0
## Lower contrast places the architecture behind the readable gameplay layer.
@export_range(0.0, 1.0) var landmark_contrast := 0.58
## Lower saturation keeps the landmark palette quieter than platforms/hazards.
@export_range(0.0, 1.0) var landmark_saturation := 0.65
const DISTANCE_SHADER := preload("res://scenes/props/backdrop/landmarks/landmark_distance.gdshader")
var panels: Array[Dictionary] = []

func configure(world: LdtkWorld) -> void:
	for panel in panels:panel.sprite.queue_free()
	panels.clear()
	var distance_material := ShaderMaterial.new()
	distance_material.shader = DISTANCE_SHADER
	distance_material.set_shader_parameter("contrast",landmark_contrast)
	distance_material.set_shader_parameter("saturation",landmark_saturation)
	for i in room_names.size():
		if i >= paintings.size() or paintings[i] == null:continue
		for room in world.rooms:
			if str(room.name) != room_names[i]:continue
			var sprite := Sprite2D.new()
			sprite.name = room_names[i]
			sprite.texture = paintings[i]
			sprite.centered = false
			sprite.material = distance_material
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.visible = false
			add_child(sprite)
			panels.append({"room":room_names[i],"bounds":world.room_rect(room),"sprite":sprite})

func frame_view(view: Rect2, viewport_size: Vector2) -> void:
	var center := view.get_center().x
	var blend := transition_width * 0.5
	for panel in panels:
		var bounds: Rect2 = panel.bounds
		var sprite: Sprite2D = panel.sprite
		var opacity := smoothstep(bounds.position.x-blend,bounds.position.x+blend,center)
		opacity *= 1.0-smoothstep(bounds.end.x-blend,bounds.end.x+blend,center)
		sprite.visible = opacity > 0.001
		panel["weight"] = opacity
		if not sprite.visible:continue
		var art_scale := maxf(viewport_size.y*painting_height/sprite.texture.get_height(),
			viewport_size.x/sprite.texture.get_width())
		sprite.scale = Vector2.ONE*art_scale
		# Fixed composition inside a room: neither a jump nor camera tracking
		# drags the distant architecture around the screen.
		var excess := sprite.texture.get_size()*art_scale-viewport_size
		sprite.position = -excess*0.5
	# Convert desired blend weights to source-over alphas. Two half-opacity
	# sprites used to leak 25% of the old panorama (and sun) at each seam.
	# The rear painting must stay opaque while the next painting fades over it.
	var remaining := 1.0
	for i in range(panels.size()-1,-1,-1):
		var panel: Dictionary = panels[i]
		var weight: float = panel.weight
		panel.sprite.modulate.a = clampf(weight/maxf(remaining,0.00001),0.0,1.0)
		remaining = maxf(0.0,remaining-weight)
