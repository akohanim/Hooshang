@tool
extends StaticBody2D
## Fluorescent-flicker rhythmic platform.
##
## Alternates between a solid collidable state and a translucent "ghost"
## wireframe state on a configurable beat. Adjacent platforms can be staggered
## via [phase_offset] so the player must time jumps to the rhythm.
##
## Visual cue on materialise: brief overexposed white flash.
## Visual cue when ghosted: pulsing cyan shimmer (sine-wave alpha).


# ── Rhythm ────────────────────────────────────────────────────────────────────
@export_group("Rhythm")
## Length of one full on/off cycle in seconds.
@export var beat_duration : float = 1.5
## Fraction of each cycle spent in the solid state (0.5 = equal on and off).
@export var duty_cycle    : float = 0.50
## How far into the cycle this platform starts. Stagger adjacent platforms
## by half a beat_duration (e.g. 0.75) to make them perfectly alternating.
@export var phase_offset  : float = 0.0

# ── Solid colours (exported so per-instance overrides are easy) ───────────────
@export_group("Colors")
@export var on_color     : Color = Color(0.38, 0.28, 0.62, 1.00)
@export var on_top_color : Color = Color(0.65, 0.52, 0.95, 1.00)

# ── Ghost colours (constant — cyan wireframe feel) ────────────────────────────
const OFF_COLOR     := Color(0.10, 0.90, 0.90, 0.20)
const OFF_TOP_COLOR := Color(0.22, 1.00, 1.00, 0.38)

# ── Flash timing ──────────────────────────────────────────────────────────────
const FLASH_DUR := 0.10   # seconds the materialise flash lasts

# ── State ─────────────────────────────────────────────────────────────────────
var _timer      : float = 0.0
var _is_solid   : bool  = true
var _was_solid  : bool  = true
var _flash_t    : float = 0.0


# ══ Lifecycle ═════════════════════════════════════════════════════════════════

func _ready() -> void:
	_timer     = fmod(phase_offset, beat_duration)
	_is_solid  = _timer < beat_duration * duty_cycle
	_was_solid = _is_solid
	_set_collision(_is_solid)
	_update_visuals()


func _process(delta: float) -> void:
	_timer = fmod(_timer + delta, beat_duration)
	_is_solid = _timer < beat_duration * duty_cycle

	if _is_solid != _was_solid:
		_was_solid = _is_solid
		_flash_t   = FLASH_DUR
		_set_collision(_is_solid)

	_flash_t = maxf(_flash_t - delta, 0.0)
	_update_visuals()


# ══ Helpers ═══════════════════════════════════════════════════════════════════

func _set_collision(solid: bool) -> void:
	if Engine.is_editor_hint():
		return
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.disabled = not solid


func _update_visuals() -> void:
	var body := get_node_or_null("Body") as Polygon2D
	var top  := get_node_or_null("Top")  as Polygon2D
	if body == null or top == null:
		return

	if _is_solid:
		# Materialise flash: lerp from over-bright white down to normal colour.
		var flash := _flash_t / FLASH_DUR   # 1.0 right after materialise → 0.0
		body.color = on_color.lerp(Color(1.6, 1.6, 1.6, 1.0), flash * 0.75)
		top.color  = on_top_color.lerp(Color(2.5, 2.5, 2.5, 1.0), flash * 0.90)
	else:
		# Ghost / wireframe: sine-wave shimmer on alpha.
		var shimmer := sin(_timer * 9.0) * 0.06
		body.color = Color(OFF_COLOR.r, OFF_COLOR.g, OFF_COLOR.b,
						   clampf(OFF_COLOR.a + shimmer, 0.08, 0.30))
		top.color  = Color(OFF_TOP_COLOR.r, OFF_TOP_COLOR.g, OFF_TOP_COLOR.b,
						   clampf(OFF_TOP_COLOR.a + shimmer, 0.20, 0.55))
