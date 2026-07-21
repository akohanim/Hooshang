extends LevelBase
## Level 1: The Office — beat scripting on top of the LevelBase plumbing.
##
## Two Rumi beats:
##   1. Intro at the door: Hooshang walks a few paces to the door, and on
##      reaching it Rumi makes his first appearance and says his line. No
##      ability granted.
##   2. At the tall pillar Hooshang can't jump: Rumi reappears and grants dash.
##
## FUTURE HOOKS:
## - Underworld shift: tween $CanvasModulate.color to the underworld palette
##   and start the stay-too-long timer here.
## - Still Sight (B&W mode): also a CanvasModulate / shader swap, see player.gd.
## - Manager's light-sweep hazard: patrol a PointLight2D + Area2D pair.

const RUMI_INTRO_LINE := "You have knocked on this door your whole life — from the inside."
const RUMI_DASH_LINE := "Some walls will not yield to a jump. Take this — and dash."
const DASH_HINT := "Press X or SHIFT to dash."
## Rumi's portrait tint in the dialogue box (alpha > 0 = show a portrait).
const RUMI_GOLD := Color(1.0, 0.82, 0.42, 1.0)
## Where Rumi stands for beat 2 — on the floor just left of the tall pillar.
const DASH_RUMI_POS := Vector2(540.0, 154.0)

var _intro_played := false
var _dash_granted := false
var _completed := false

@onready var rumi: AnimatedSprite2D = $Rumi
@onready var rumi_light: PointLight2D = $RumiLight
@onready var dialogue: DialogueBox = $DialogueBox
@onready var end_screen: CanvasLayer = $EndScreen


func _ready() -> void:
	super()
	$IntroTrigger.body_entered.connect(_on_intro_trigger_entered)
	$DashTrigger.body_entered.connect(_on_dash_trigger_entered)
	$ExitTrigger.body_entered.connect(_on_exit_entered)
	# Player keeps control at start and walks the few paces to the door.


# ---- Beat 1: intro at the door (Rumi's first appearance, no ability) --------
func _on_intro_trigger_entered(body: Node2D) -> void:
	if body != player or _intro_played:
		return
	_intro_played = true
	_play_intro()


func _play_intro() -> void:
	player.input_locked = true
	await _rumi_appear($Rumi.position)
	await dialogue.say("Rumi", RUMI_INTRO_LINE, RUMI_GOLD)
	await _rumi_vanish()
	player.input_locked = false


# ---- Beat 2: at the unjumpable pillar, Rumi grants the dash ------------------
func _on_dash_trigger_entered(body: Node2D) -> void:
	if body != player or _dash_granted:
		return
	_dash_granted = true
	_grant_dash_scene()


func _grant_dash_scene() -> void:
	player.input_locked = true
	await _rumi_appear(DASH_RUMI_POS)
	await dialogue.say("Rumi", RUMI_DASH_LINE, RUMI_GOLD)

	# The gift: a golden pulse on Hooshang, then dash is his.
	# (self_modulate so it doesn't fight the dash-tint logic on modulate.)
	var pulse := create_tween()
	pulse.tween_property(player.visual, "self_modulate", Color(3.0, 2.6, 1.6), 0.15)
	pulse.tween_property(player.visual, "self_modulate", Color.WHITE, 0.35)
	player.has_dash = true

	await dialogue.say("", DASH_HINT)  # system hint, no portrait
	await _rumi_vanish()
	player.input_locked = false


# ---- Shared Rumi entrance/exit ---------------------------------------------
## Fade Rumi in at `rest` with a small descend, and raise his warm gold light.
func _rumi_appear(rest: Vector2) -> void:
	rumi.position = rest + Vector2(0.0, -10.0)
	rumi.modulate.a = 0.0
	rumi_light.position = rest + Vector2(0.0, -19.0)
	rumi_light.energy = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(rumi, "modulate:a", 1.0, 0.5)
	t.tween_property(rumi, "position:y", rest.y, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(rumi_light, "energy", 1.4, 0.5)
	await t.finished


func _rumi_vanish() -> void:
	var t := create_tween().set_parallel()
	t.tween_property(rumi, "modulate:a", 0.0, 0.5)
	t.tween_property(rumi_light, "energy", 0.0, 0.5)
	await t.finished


func _on_exit_entered(body: Node2D) -> void:
	if body != player or _completed:
		return
	_completed = true
	print("LEVEL COMPLETE")
	player.input_locked = true
	end_screen.visible = true
