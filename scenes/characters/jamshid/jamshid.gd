class_name Jamshid
extends Node2D
## Hooshang's best friend and cousin. A visual actor for authored cutscenes.
## Movement and story timing belong to the scene directing him.

const FACES := {
	"friendly": preload("res://assets/characters/jamshid/portraits_v2/jamshid_friendly.png"),
	"joyful": preload("res://assets/characters/jamshid/portraits_v2/jamshid_joyful.png"),
	"worried": preload("res://assets/characters/jamshid/portraits_v2/jamshid_worried.png"),
	"sad": preload("res://assets/characters/jamshid/portraits_v2/jamshid_sad.png"),
	"determined": preload("res://assets/characters/jamshid/portraits_v2/jamshid_determined.png"),
	"excited": preload("res://assets/characters/jamshid/portraits_v2/jamshid_excited.png"),
}
const NATIVE_HEIGHT := 15.0
const SOURCE_SCALE := 0.375

## Standing height in world pixels; sitting and crouching stay proportionally lower.
@export_range(8.0, 64.0, 1.0) var standing_height := 15.0
## Pose to play when this actor enters the scene.
@export_enum("idle", "walk", "sit", "jump") var initial_pose := "idle"
## Start facing left; every source frame faces right.
@export var facing_left := false

@onready var visual: AnimatedSprite2D = $Visual


func _ready() -> void:
	visual.animation_finished.connect(_on_animation_finished)
	play_pose(initial_pose)
	face_left(facing_left)


func play_pose(pose: String) -> void:
	if not visual.sprite_frames.has_animation(pose):
		push_warning("Unknown Jamshid pose: " + pose)
		return
	var ratio: float = standing_height / NATIVE_HEIGHT
	var factor: float = SOURCE_SCALE * ratio
	visual.position.y = -6.0 * ratio
	visual.scale = Vector2(-factor if facing_left else factor, factor)
	visual.play(pose)


func face_left(value: bool) -> void:
	facing_left = value
	visual.scale.x = -absf(visual.scale.x) if value else absf(visual.scale.x)


static func portrait(emotion: String = "friendly") -> Texture2D:
	return FACES.get(emotion, FACES["friendly"])


func _on_animation_finished() -> void:
	if visual.animation == &"jump":
		play_pose("idle")
