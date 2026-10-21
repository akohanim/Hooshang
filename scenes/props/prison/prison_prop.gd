extends Node2D
## Reusable key, shutter and cage; progress belongs to the world.
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
var patrol_frames: Array[AtlasTexture] = []
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
		sprite.scale = Vector2(2,2)
		sprite.position.y = -8
		z_index = 5
		var bright := CanvasItemMaterial.new()
		bright.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = bright
		sprite.use_parent_material = true
	elif kind == "Cage":
		sprite.texture = preload("res://ldtk/art/prison/cage_closed.png")
		($Sensor/Shape.shape as RectangleShape2D).size = Vector2(88,44)
		($Barrier/Shape.shape as RectangleShape2D).size = Vector2(60,36)
		barrier.disabled = false
	elif kind == "ShortcutDoor":
		sprite.texture = preload("res://ldtk/art/prison/door_closed.png")
		sprite.scale = prop_size / Vector2(32,40)
		(barrier.shape as RectangleShape2D).size = prop_size
		# A hatch door (wider than tall) is exactly the cell it is drawn in, at
		# the seam. It used to hang 64px down past it, which reached 32px into the
		# NEIGHBOURING room as an invisible block: it pinned anyone standing on
		# the hub step under a locked hatch. A one-cell plug leaves at most a
		# one-cell dip on the far side, which is never a pocket he cannot leave.
		barrier.disabled = false
	elif kind == "Patrol":
		# Water tiles must not tint away a lethal patrol's established outline.
		z_index = 4
		# Reuse Act 2's established pink-rimmed thought art. Crop the empty
		# upper half of each frame so the visible body encloses the tested sensor.
		for frame in 4:
			var texture := AtlasTexture.new()
			texture.atlas = preload("res://assets/hazards/act2_dark_thought.png")
			texture.region = Rect2(frame*16,7,16,9)
			texture.filter_clip = true
			patrol_frames.append(texture)
		sprite.texture = patrol_frames[0]
		sprite.scale = Vector2(1.25,1.75)
		var bright := CanvasItemMaterial.new()
		bright.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		sprite.material = bright
		($Sensor/Shape.shape as RectangleShape2D).size = Vector2(12,12)
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
		"Patrol": body.die()

func _physics_process(delta: float) -> void:
	if kind != "Patrol" or mission == null: return
	if not mission.is_room_active(get_parent().get_parent()): return
	clock += delta
	sprite.texture = patrol_frames[posmod(int(clock / 0.14) + entity_iid.hash(),4)]
	var amplitude := absf(float(fields.get("Amplitude",18.0)))
	var angle := clock*2.0*float(fields.get("Speed",1.0)) + float(fields.get("Phase",0.0))
	var motion := str(fields.get("Motion","Vertical")).get_slice(".",1)
	var offset := Vector2(0,sin(angle)*amplitude)
	if motion == "Horizontal": offset = Vector2(sin(angle)*amplitude,0)
	elif motion == "Circle": offset = Vector2(cos(angle),sin(angle))*amplitude
	position = origin + offset

func _draw() -> void:
	if kind == "PrisonSign":
		var label := str(fields.get("Text",""))
		if mission != null and mission.rescued and label == "FREE JAMSHID  /  FOUR KEYS":
			label = "COURTYARD LEFT"
		draw_string(FONT,Vector2(-FONT.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x/2,0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("e8d6ab"))
	elif kind == "Key":
		draw_arc(Vector2(0,-8),12,0,TAU,24,Color("fff2c9"),1)
		var label := key_id.to_upper()+" KEY"
		draw_string(FONT,label_offset(label,-24),label,HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("fff2c9"))
	elif kind == "Cage":
		var locks := lock_ids()
		for i in locks.size():
			if mission == null or not mission.inserted.has(locks[i]):
				draw_texture(_tile(36+IDS.find(locks[i])),Vector2(-22+i*12,2))
	elif kind == "ShortcutDoor" and IDS.has(key_id):
		draw_circle(Vector2.ZERO,3,COLORS[IDS.find(key_id)])

## Keep pickup names inside their authored room, including keys near a seam.
func label_offset(label: String, baseline: float) -> Vector2:
	var width := FONT.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x
	var x := -width / 2.0
	var room := get_parent().get_parent()
	if room is LDTKLevel:
		x = clampf(position.x + x, 8.0, float(room.size.x) - width - 8.0) - position.x
	return Vector2(x, baseline)

func lock_ids() -> Array[String]:
	var result: Array[String] = []
	for i in 4:
		var value := str(fields.get("Lock%d" % (i+1),IDS[i])).get_slice(".",1)
		if value == "": value = str(fields.get("Lock%d" % (i+1),IDS[i]))
		if value in IDS and not result.has(value): result.append(value)
	return result
