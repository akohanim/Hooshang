extends Area2D
## Floating paper document. Collecting it arms the player's next dash with a
## paper trail — solid platforms left in the dash's wake for ~1.5 s.
## Respawns automatically after RESPAWN_TIME seconds.

const RESPAWN_TIME := 8.0    # s before the item reappears after being collected
const BOB_SPEED    := 2.2    # rad/s — vertical bob rate
const BOB_AMP      := 4.0    # px   — vertical bob amplitude
const ROT_SPEED    := 0.55   # rad/s — slow rotation

var _active : bool  = true
var _base_y : float = 0.0
var _bob_t  : float = 0.0

@onready var _shape : CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if not _active:
		return
	_bob_t      += delta
	position.y   = _base_y + sin(_bob_t * BOB_SPEED) * BOB_AMP
	rotation    += ROT_SPEED * delta


func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return
	if body.has_method("enable_paper_trail"):
		body.enable_paper_trail()
		_collect()


func _collect() -> void:
	_active = false
	rotation = 0.0
	_shape.set_deferred("disabled", true)

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(3.0, 3.0, 2.0, 1.0), 0.06)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 0.5, 0.0), 0.30)
	tween.tween_callback(hide)
	tween.tween_interval(RESPAWN_TIME - 0.36)
	tween.tween_callback(_respawn)


func _respawn() -> void:
	_active = true
	_shape.set_deferred("disabled", false)
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	position.y = _base_y
	_bob_t     = 0.0
	show()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.35)
