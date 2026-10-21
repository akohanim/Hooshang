class_name SeaMemory
extends Node2D
## One of the things he kept, sunk in the Drowned Office (Act III, chapter III):
## a name plate, a photograph, a ticket, a letter, a spray can. It floats where
## it was dropped, lit faintly from inside. Touch it and Hooshang remembers —
## his `lines`, a DialogueScript in his own voice (`(state)` names his face) —
## and then it rises and goes out: let go.
##
## No reward but the line. A memory remembered stays remembered (SeaWorld saves
## the ids); walking back past it finds nothing there.
##
## A memory with no lines is a silent beat — he holds it a moment and says
## nothing (the spray can). Act3Beats listens to `remembered` for the ones a
## scene follows on from.

signal remembered(memory: SeaMemory)

const SHEET := preload("res://assets/act3/sea/memories.png")
const KINDS := ["nameplate", "photo", "ticket", "letter", "can", "pearl"]
const FRAME := 16
const GLOW := preload("res://assets/light_radial.png")

@export var kind := "nameplate"
@export_multiline var lines := ""
## Stable id for the save (room name + kind, set by the import).
@export var memory_id := ""

var done := false
var _sprite: Sprite2D
var _halo: Sprite2D
var _time := 0.0
var _origin := Vector2.ZERO
var _busy := false


func _ready() -> void:
	add_to_group("sea_memory")
	_origin = position
	z_index = 2
	_halo = Sprite2D.new()
	_halo.texture = GLOW
	_halo.scale = Vector2.ONE * 0.35
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_halo.material = add
	_halo.modulate = Color(1.0, 0.82, 0.5, 1.0) * 0.45
	add_child(_halo)
	_sprite = Sprite2D.new()
	var tex := AtlasTexture.new()
	tex.atlas = SHEET
	tex.region = Rect2(maxi(KINDS.find(kind), 0) * FRAME, 0, FRAME, FRAME)
	_sprite.texture = tex
	add_child(_sprite)
	_time = fposmod(position.x * 0.021, TAU)


## Already remembered on a previous visit (SeaWorld, from the save).
func mark_done() -> void:
	done = true
	visible = false


func _process(delta: float) -> void:
	_time += delta
	if not _busy:
		position = _origin + Vector2(0.0, roundf(sin(_time * 1.4) * 2.0))
		_sprite.rotation = sin(_time * 0.9) * 0.12
	_halo.modulate.a = 0.75 + 0.25 * sin(_time * 2.1)


func _physics_process(_delta: float) -> void:
	if done or _busy:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.state == Player.State.DEAD or player.input_locked:
		return
	if player.hitbox_rect().grow(3.0).has_point(global_position):
		_remember(player)


func _remember(player: Player) -> void:
	_busy = true
	done = true
	Sfx.play(&"memory")
	Dialogue.begin_conversation(self, player, true)
	var beats := DialogueScript.parse(lines, Act1Beats.FACES, "SeaMemory")
	if beats.is_empty():
		await get_tree().create_timer(1.6, false).timeout
	for beat: Dictionary in beats:
		await Dialogue.say("Hooshang", beat["text"], Act1Beats.HOOSHANG_PALE,
			Act1Beats.FACES.get(beat["face"]), DialogueBox.Side.LEFT)
	Dialogue.end_conversation()
	remembered.emit(self)
	# Let go: it rises a little, brightens, and is gone.
	var t := create_tween().set_parallel()
	t.tween_property(self, "position:y", position.y - 18.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(_sprite, "modulate", Color(3.0, 2.6, 1.8, 0.0), 1.4)
	t.tween_property(_halo, "scale", Vector2.ONE * 0.9, 1.4)
	t.tween_property(_halo, "modulate:a", 0.0, 1.4)
	await t.finished
	visible = false
	_busy = false
