class_name HooshangDialogueAnimator
extends Control
## Hooshang Dialogue Animator: Manages 9-frame emotional sub-matrix animations
## (3 mouth states x 3 eye states) for character 'Hooshang'.
##
## Implements:
##   - play_expression(emotion: String, blink_rate: float = 0.25)
##   - play_dialogue(text: String, emotion: String = "", speed: float = 0.05)
##   - sync with typewriter reveals and natural semi-random eye blinks.

signal expression_changed(new_emotion: String)
signal dialogue_completed
signal blink_triggered

enum MouthState { CLOSED = 0, MID_TALK = 1, TALK = 2 }
enum EyeState { OPEN = 0, MID_BLINK = 1, CLOSED = 2 }

const EMOTIONS := ["neutral", "happy", "angry", "sad", "surprised"]

## Aliases mapping old or dramatic state names to the 5 primary matrix emotions
const EMOTION_ALIASES := {
	"neutral": "neutral",
	"happy": "happy",
	"angry": "angry",
	"sad": "sad",
	"surprised": "surprised",
	"dazed": "sad",
	"hesitant": "neutral",
	"skeptical": "angry",
	"annoyed": "angry",
	"vulnerable": "sad",
	"shocked": "surprised",
	"confused": "neutral",
	"wary": "angry",
	"unconvinced": "angry",
	"deflecting": "neutral",
	"flat": "neutral",
}

const SPRITE_BASE_PATH := "res://sprites/hooshang/"

@export var current_emotion: String = "neutral"
@export var default_blink_rate: float = 0.25
@export var talk_speed: float = 0.05

var mouth_state: int = MouthState.CLOSED
var eye_state: int = EyeState.OPEN
var is_talking: bool = false

# Internal timing
var _blink_timer: float = 0.0
var _blink_phase_timer: float = 0.0
var _blink_phase: int = 0  # 0: open, 1: mid_blink down, 2: fully closed, 3: mid_blink up
var _talk_timer: float = 0.0
var _talk_step: int = 0

# Dialogue playback tracking
var _active_dialogue_text: String = ""
var _dialogue_char_index: int = 0
var _dialogue_speed: float = 0.05
var _is_revealing_dialogue: bool = false

# Texture cache: emotion -> Array of 9 Texture2D
var _matrix_textures: Dictionary = {}

@onready var texture_display: TextureRect = $TextureDisplay if has_node("TextureDisplay") else null
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null


func _ready() -> void:
	_setup_display_nodes()
	_load_all_matrix_textures()
	play_expression(current_emotion, default_blink_rate)


func _setup_display_nodes() -> void:
	# Ensure display nodes exist and fill the control
	if texture_display == null:
		texture_display = TextureRect.new()
		texture_display.name = "TextureDisplay"
		texture_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		texture_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_display.set_anchors_preset(PRESET_FULL_RECT)
		texture_display.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(texture_display)

	if animated_sprite == null:
		animated_sprite = AnimatedSprite2D.new()
		animated_sprite.name = "AnimatedSprite2D"
		animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		animated_sprite.visible = false  # TextureRect is the primary UI canvas renderer
		add_child(animated_sprite)


func _load_all_matrix_textures() -> void:
	for emo in EMOTIONS:
		var frames: Array[Texture2D] = []
		for i in range(1, 10):
			var path := "%s%s_matrix_%02d.png" % [SPRITE_BASE_PATH, emo, i]
			var tex := load(path) as Texture2D
			if tex == null:
				push_warning("Failed to load matrix texture: " + path)
			frames.append(tex)
		_matrix_textures[emo] = frames


## Normalizes an emotion name through alias mapping
func resolve_emotion(raw_name: String) -> String:
	var clean := raw_name.to_lower().strip_edges()
	clean = clean.replace("hooshang_", "")
	return EMOTION_ALIASES.get(clean, "neutral")


## Function 1: Play expression with semi-random blinks
func play_expression(emotion: String, blink_rate: float = 0.25) -> void:
	var target_emo := resolve_emotion(emotion)
	current_emotion = target_emo
	default_blink_rate = maxf(0.05, blink_rate)

	# Reset expression state
	mouth_state = MouthState.CLOSED
	eye_state = EyeState.OPEN
	_blink_phase = 0
	_reset_blink_interval()
	_update_rendered_frame()
	expression_changed.emit(current_emotion)


## Function 2: Play dialogue, synchronizing talk frames with text reveal speed
func play_dialogue(text: String, emotion: String = "", speed: float = 0.05) -> void:
	if emotion != "":
		play_expression(emotion, default_blink_rate)

	_active_dialogue_text = text
	_dialogue_char_index = 0
	_dialogue_speed = maxf(0.01, speed)
	_talk_timer = 0.0
	_talk_step = 0
	_is_revealing_dialogue = true
	set_talking(true)


## Toggle mouth talking state directly (e.g. called from external typewriter)
func set_talking(talking: bool) -> void:
	is_talking = talking
	if not is_talking:
		mouth_state = MouthState.CLOSED
		_is_revealing_dialogue = false
		_update_rendered_frame()


func _reset_blink_interval() -> void:
	# Semi-random blink interval based on blink_rate
	var base_gap := 1.0 / default_blink_rate
	_blink_timer = randf_range(base_gap * 0.7, base_gap * 1.3)


func _process(delta: float) -> void:
	_process_blinking(delta)
	_process_talking(delta)
	_process_dialogue_text(delta)


func _process_blinking(delta: float) -> void:
	if _blink_phase == 0:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			# Initiate blink cycle: OPEN -> MID_BLINK -> CLOSED -> MID_BLINK -> OPEN
			_blink_phase = 1
			_blink_phase_timer = 0.04
			eye_state = EyeState.MID_BLINK
			_update_rendered_frame()
			blink_triggered.emit()
	else:
		_blink_phase_timer -= delta
		if _blink_phase_timer <= 0.0:
			if _blink_phase == 1:
				# Transition to fully closed
				_blink_phase = 2
				_blink_phase_timer = 0.06
				eye_state = EyeState.CLOSED
				_update_rendered_frame()
			elif _blink_phase == 2:
				# Re-opening: transition to mid-blink
				_blink_phase = 3
				_blink_phase_timer = 0.04
				eye_state = EyeState.MID_BLINK
				_update_rendered_frame()
			elif _blink_phase == 3:
				# Blink finished: back to open
				_blink_phase = 0
				eye_state = EyeState.OPEN
				_reset_blink_interval()
				_update_rendered_frame()


func _process_talking(delta: float) -> void:
	if not is_talking:
		return

	_talk_timer -= delta
	if _talk_timer <= 0.0:
		_talk_timer = talk_speed
		_talk_step = (_talk_step + 1) % 4
		# Pattern: MID_TALK -> TALK -> MID_TALK -> CLOSED/REPEAT
		match _talk_step:
			0: mouth_state = MouthState.MID_TALK
			1: mouth_state = MouthState.TALK
			2: mouth_state = MouthState.MID_TALK
			3: mouth_state = MouthState.TALK
		_update_rendered_frame()


func _process_dialogue_text(delta: float) -> void:
	if not _is_revealing_dialogue:
		return

	# If text length reached, stop dialogue reveal
	if _dialogue_char_index >= _active_dialogue_text.length():
		_is_revealing_dialogue = false
		set_talking(false)
		dialogue_completed.emit()


## Updates the current frame based on (mouth_state, eye_state)
func _update_rendered_frame() -> void:
	var frames: Array = _matrix_textures.get(current_emotion, [])
	if frames.is_empty():
		return

	var frame_idx: int = clampi(mouth_state * 3 + eye_state, 0, 8)
	var tex: Texture2D = frames[frame_idx]

	if texture_display != null and tex != null:
		texture_display.texture = tex


## Direct matrix frame query helper
func get_current_frame_texture() -> Texture2D:
	var frames: Array = _matrix_textures.get(current_emotion, [])
	if frames.is_empty():
		return null
	var frame_idx: int = clampi(mouth_state * 3 + eye_state, 0, 8)
	return frames[frame_idx]
