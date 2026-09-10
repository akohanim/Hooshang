extends TileMapLayer
## Background masonry scrolls between the far painting (0.2) and solids (1.0).
@export var scroll_factor := 0.7
var origin := Vector2.ZERO
func _ready() -> void:
	origin = position
func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		position = origin + ((camera.get_screen_center_position() - Vector2(96,48)) * (1.0-scroll_factor)).round()
