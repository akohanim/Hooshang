extends Node2D
## Non-tiled cinematic paintings. Gameplay art and viewport sampling stay intact.
const IMAGES := {
	"arrest": preload("res://assets/backdrop/act2_memories/source/arrest.png"),
	"corridor": preload("res://assets/backdrop/act2_memories/source/corridor.png"),
	"mother": preload("res://assets/backdrop/act2_memories/source/mother.png"),
	"rain": preload("res://assets/backdrop/act2_memories/source/rain.png")
}
var current := ""
var clock := 0.0
func show_memory(kind: String) -> void:
	current = kind
	$Painting.texture = IMAGES[kind]
	$Poem.visible = kind == "rain"
	clock = 0.0
	show()
	queue_redraw()
func _process(delta: float) -> void:
	if visible and current == "rain":
		clock += delta
		queue_redraw()
func _draw() -> void:
	if current != "rain": return
	for i in 35:
		var at := Vector2(fposmod(i*79.0-clock*9.0,320.0),fposmod(i*43.0+clock*110.0,180.0))
		draw_line(at.round(),(at+Vector2(-1,4)).round(),Color(.65,.75,.82,.16),1)
