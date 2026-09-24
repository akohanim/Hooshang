extends Node2D
const POWER_GATE = preload("res://scenes/props/chase/powers/power_gate.gd")
## Room-local trigger. A spawn inside it must leave before it can fire.
@export var size := Vector2(16,48)
@export_enum("Charge", "Eruption") var power := 0
@export var encounter_id := "A"
## Legacy serialized fields: retained for old LDtk imports, no longer used.
## Charges always aim from the live boss at the live player.
@export var aim_at_player := true
@export var angle := 180.0
@export var launch_offset := Vector2.ZERO
@export var use_launch_offset := false
@export var warning_time := .8
@export var speed := 240.0
@export var distance := 240.0
@export var recovery_time := .7
@export var sequence_delay := .35
@export var repeat_delay := 0.0
var spent := false
var armed := false
var cooldown := 0.0
var player: Player
var world: LdtkWorld

func _ready() -> void:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is LdtkWorld:
			world = ancestor
			break
		ancestor = ancestor.get_parent()
	add_to_group("darkshang_power_trigger")

func reset() -> void:
	spent = false
	armed = false
	cooldown = 0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		if player == null: return
		player.died.connect(reset)
	if world != null and ((world.current_room == null or not world.current_room.is_ancestor_of(self)) or world.transition_target != null):
		reset()
		return
	if player.state == Player.State.DEAD or player.input_locked: return
	cooldown = maxf(0,cooldown-delta)
	var inside := Rect2(global_position-size/2,size).intersects(player.hitbox_rect())
	if not inside:
		armed = true
		return
	if not armed or spent or cooldown > 0: return
	if activate():
		armed = false
		spent = repeat_delay <= 0
		cooldown = maxf(.1,repeat_delay)

func activate() -> bool:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if player == null: return false
	var shadow: Darkshang = POWER_GATE.caster_for(self)
	if shadow == null or not shadow.powers_available(): return false
	if power == 1:
		var found := false
		for strip in get_tree().get_nodes_in_group("shadow_eruption"):
			if strip.get_parent() == get_parent() and strip.encounter_id == encounter_id:
				found = strip.activate(maxi(0,strip.sequence)*maxf(0,sequence_delay)) or found
		return found
	return shadow.locked_charge(warning_time,speed,distance,recovery_time)
