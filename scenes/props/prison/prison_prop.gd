extends Node2D
## Reusable key, shutter, cage and checkpoint; progress belongs to the world.
@export var kind := "Key"
@export var entity_iid := ""
@export var fields: Dictionary = {}
@export var prop_size := Vector2(16,16)
const COLORS := [Color("b54c41"),Color("548f68"),Color("449bb8"),Color("deaf4a")]
const FONT := preload("res://assets/fonts/pixel5x7.fnt")
const IDS := ["Red","Green","Blue","Gold"]
var mission: Node
var key_id := ""
var origin := Vector2.ZERO
var clock := 0.0
@onready var sprite: Sprite2D = $Sprite
@onready var barrier: CollisionShape2D = $Barrier/Shape

func _ready() -> void:
	origin = position
	barrier.shape = barrier.shape.duplicate()
	$Sensor/Shape.shape = $Sensor/Shape.shape.duplicate()
	$Sensor.body_entered.connect(_touch)
	key_id = str(fields.get("KeyId", "")).get_slice(".",1)
	if key_id == "": key_id = str(fields.get("KeyId", ""))
	if kind == "Key":
		sprite.texture = _tile(32 + maxi(0,IDS.find(key_id)))
	elif kind == "Cage":
		sprite.texture = preload("res://ldtk/art/prison/cage_closed.png")
		($Sensor/Shape.shape as RectangleShape2D).size = Vector2(88,44)
		($Barrier/Shape.shape as RectangleShape2D).size = Vector2(60,36)
		barrier.disabled = false
	elif kind == "ShortcutDoor":
		sprite.texture = preload("res://ldtk/art/prison/door_closed.png")
		sprite.scale = prop_size / Vector2(32,40)
		(barrier.shape as RectangleShape2D).size = prop_size
		barrier.disabled = false
	elif kind == "Patrol":
		sprite.texture = preload("res://assets/props/key/key.png")
		sprite.visible = false
		($Sensor/Shape.shape as RectangleShape2D).size = Vector2(12,12)
	elif kind == "Checkpoint":
		($Sensor/Shape.shape as RectangleShape2D).size = Vector2(20,20)
	queue_redraw()

func _tile(index: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = preload("res://ldtk/art/prison/school.png")
	a.region = Rect2((index%16)*8,(index/16)*8,8,8)
	return a

func bind(owner_world: Node) -> void:
	mission = owner_world
	if kind == "ShortcutDoor":
		key_id = mission.key_for_reference(fields.get("Key", ""))
	refresh()

func refresh() -> void:
	if mission == null: return
	if kind == "Key": visible = not mission.collected.has(key_id)
	if kind == "ShortcutDoor":
		var opened: bool = mission.collected.has(key_id)
		barrier.set_deferred("disabled",opened)
		sprite.texture = preload("res://ldtk/art/prison/door_open.png") if opened else preload("res://ldtk/art/prison/door_closed.png")
	if kind == "Cage":
		barrier.set_deferred("disabled",mission.rescued)
		sprite.texture = preload("res://ldtk/art/prison/cage_open.png") if mission.rescued else preload("res://ldtk/art/prison/cage_closed.png")
	queue_redraw()

func _touch(body: Node2D) -> void:
	if mission == null or body != mission.player or not mission.current_room.is_ancestor_of(self): return
	if body.state == Player.State.DEAD or mission._transitioning: return
	match kind:
		"Key": mission.collect_key(key_id,global_position)
		"Cage": mission.insert_keys(self)
		"Checkpoint": mission.set_story_checkpoint(mission.current_room,mission._safe_landing(mission.current_room,global_position))
		"Patrol": body.die()

func _physics_process(delta: float) -> void:
	if kind != "Patrol" or mission == null: return
	if not mission.is_room_active(get_parent().get_parent()): return
	clock += delta
	var amplitude := absf(float(fields.get("Amplitude",18.0)))
	var angle := clock*2.0*float(fields.get("Speed",1.0)) + float(fields.get("Phase",0.0))
	var motion := str(fields.get("Motion","Vertical")).get_slice(".",1)
	var offset := Vector2(0,sin(angle)*amplitude)
	if motion == "Horizontal": offset = Vector2(sin(angle)*amplitude,0)
	elif motion == "Circle": offset = Vector2(cos(angle),sin(angle))*amplitude
	position = origin + offset
	queue_redraw()

func _draw() -> void:
	if kind == "PrisonSign":
		var label := str(fields.get("Text",""))
		draw_string(FONT,Vector2(-FONT.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x/2,0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("e8d6ab"))
	elif kind == "Checkpoint":
		draw_line(Vector2(-4,6),Vector2(-4,-8),Color("d9c495"),1)
		draw_colored_polygon(PackedVector2Array([Vector2(-3,-8),Vector2(5,-5),Vector2(-3,-2)]),Color("74b8aa"))
	elif kind == "Cage":
		var locks := lock_ids()
		for i in locks.size():
			if mission == null or not mission.inserted.has(locks[i]):
				draw_texture(_tile(36+IDS.find(locks[i])),Vector2(-22+i*12,2))
	elif kind == "ShortcutDoor" and IDS.has(key_id):
		draw_circle(Vector2.ZERO,3,COLORS[IDS.find(key_id)])
	elif kind == "Patrol":
		for i in 5:draw_circle(Vector2(sin(i*2.3)*4,cos(i*2.3)*3),4,Color("665371"))
		draw_circle(Vector2(-2,-1),1,Color("e6ceb1"));draw_circle(Vector2(2,-1),1,Color("e6ceb1"))

func lock_ids() -> Array[String]:
	var result: Array[String] = []
	for i in 4:
		var value := str(fields.get("Lock%d" % (i+1),IDS[i])).get_slice(".",1)
		if value == "": value = str(fields.get("Lock%d" % (i+1),IDS[i]))
		if value in IDS and not result.has(value): result.append(value)
	return result
