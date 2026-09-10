class_name Jamshid
extends Node2D
## Hooshang's best friend and cousin. A visual actor for authored cutscenes.
## Movement and story timing belong to the scene directing him.

const FACES := {
	"friendly": preload("res://assets/characters/jamshid/portraits/jamshid_friendly.tres"),
	"joyful": preload("res://assets/characters/jamshid/portraits/jamshid_joyful.tres"),
	"worried": preload("res://assets/characters/jamshid/portraits/jamshid_worried.tres"),
	"sad": preload("res://assets/characters/jamshid/portraits/jamshid_sad.tres"),
	"determined": preload("res://assets/characters/jamshid/portraits/jamshid_determined.tres"),
	# A state the script asks for that has no drawing of its own, pointed at the
	# nearest one that does — the same aliasing Act1Beats.FACES uses, and listed
	# here rather than having the beat just say "joyful", because the beat is
	# where the ACTING is described: when the sheet grows an excited face this
	# gets its own art and not one line of dialogue moves.
	"excited": preload("res://assets/characters/jamshid/portraits/jamshid_joyful.tres"),
}
const SOURCE_HEIGHT := {"idle": 740.0, "walk": 500.0, "sit": 800.0, "jump": 429.0}

## Standing height in world pixels; sitting and crouching stay proportionally lower.
@export_range(8.0, 64.0, 1.0) var standing_height := 16.0
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
	if not SOURCE_HEIGHT.has(pose):
		push_warning("Unknown Jamshid pose: " + pose)
		return
	var factor: float = standing_height / SOURCE_HEIGHT[pose]
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
