class_name StarField
extends Node2D
## A field of twinkling stars for Act 2's night. Drawn as small deterministic
## dots across the 320x180 game screen (tools nothing — pure _draw), with an
## `amount` (0..1) the encounter tweens up at night and back down at dawn.
##
## DRAWN UNSHADED, so the night's CanvasModulate cannot reach it. The day/night
## tween is a CanvasModulate (see Act2Beats), which MULTIPLIES every ordinary
## canvas item down to the night colour — a star sitting under it would be
## crushed to nothing exactly when it is meant to shine. Unshaded canvas items
## escape CanvasModulate entirely (measured in this project: 0.047 shaded vs
## 1.000 unshaded — the same trick DarkThought's halo and the lemon glow use),
## so `amount` alone controls the stars. It sits in the world's Backdrop, drawn
## over the sky and under the characters.

## Screen the stars are spread across — the game's own 320x180 surface.
const SCREEN := Vector2(320, 180)
## How many stars, and how far down the screen they reach (the horizon sits
## a bit above the room's floor, so stars only fill the upper sky band).
@export var count := 70
@export var horizon_y := 120.0
## 0 = invisible (day), 1 = full night. Tweened by the beat.
@export var amount := 0.0:
	set(value):
		amount = clampf(value, 0.0, 1.0)
		queue_redraw()
## Twinkle speed; each star has its own phase so they do not pulse in lockstep.
@export var twinkle_speed := 2.2
## Seed for the star layout — fixed, so the same sky comes back every run
## (same reason the thought tiles hash their layout instead of using RNG).
@export var seed := 20260906

var _stars: Array = []
var _t := 0.0
var _meteor := -1.0
var _meteor_start := Vector2.ZERO
var shots_fired := 0


func _ready() -> void:
	# Unshaded, so the night CanvasModulate cannot dim the stars — see the note
	# at the top of this file.
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m
	_build()
	set_process(true)


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_stars.clear()
	for i in count:
		_stars.append({
			"pos": Vector2(rng.randf() * SCREEN.x, rng.randf() * horizon_y),
			"size": 1.0 if rng.randf() < 0.7 else 2.0,
			"phase": rng.randf() * TAU,
			"base": rng.randf_range(0.5, 1.0),
		})


func _process(delta: float) -> void:
	if amount <= 0.0:
		return
	if _meteor >= 0.0:
		_meteor += delta
		if _meteor > 0.85:
			_meteor = -1.0
	_t += delta * twinkle_speed
	queue_redraw()


func _draw() -> void:
	if amount <= 0.0:
		return
	for s in _stars:
		var tw: float = 0.65 + 0.35 * sin(_t + s["phase"])
		var a: float = amount * s["base"] * tw
		var c := Color(1.0, 0.98, 0.9, a)
		var p: Vector2 = s["pos"].round()
		var r: float = s["size"]
		draw_rect(Rect2(p, Vector2(r, r)), c)
		if r >= 2.0:  # a cross-glint on the brighter ones
			draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), Color(1, 1, 1, a * 0.5))
			draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), Color(1, 1, 1, a * 0.5))

	if _meteor >= 0.0:
		var head := _meteor_start + Vector2(95, 35) * _meteor
		for i in 12:
			var pixel := (head - Vector2(i, i * 0.36)).round()
			draw_rect(Rect2(pixel, Vector2.ONE), Color(1, 0.95, 0.8, amount * (1.0 - i / 12.0)))


func shoot(index: int) -> void:
	_meteor_start = Vector2(35 + index * 66, 12 + index * 8)
	_meteor = 0.0
	shots_fired += 1


func shift_sky(pixels: float) -> void:
	for star in _stars:
		star["pos"].x = fposmod(star["pos"].x + pixels, SCREEN.x)
	queue_redraw()
