extends ThoughtHazardLayer
## Act One presentation of the same paintable, pass-through thought cells.
const DUST := preload("res://scenes/props/hazards/thought_dust/ThoughtDust.tscn")
var dust: Node2D
var _layout: Array[Vector2i] = []

func _ready() -> void:
	# Only this layer's atlas is hidden; the procedural child remains visible.
	self_modulate.a = 0.0
	changed.connect(_refresh)
	_refresh()
	set_process(false)

func _refresh() -> void:
	var cells := get_used_cells()
	if cells == _layout:
		return
	_layout = cells
	if is_instance_valid(dust):
		dust.queue_free()
		dust = null
	if cells.is_empty():
		return
	dust = DUST.instantiate()
	add_child(dust)
	dust.configure(self)
