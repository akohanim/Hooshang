@tool
extends Node2D
## The supplied open / half-closed / closed sheet, sampled without changing art.
## Animation is purely visual and never changes Darkshang's catch box.
const SHEET := preload("res://assets/characters/darkshang/darkshang_blink_sheet.png")
const FRAME_SIZE := Vector2(724, 724)
## Seconds between blinks, including the blink itself.
@export var blink_interval := 3.7
## Total time for half-closed -> closed -> half-closed -> open.
@export var blink_duration := 0.24
## Native-pixel vertical drift while floating.
@export var float_amplitude := 2.0
## Width of each square source frame in the game's native pixels.
@export var draw_size := 72.0
## How far individual lobes roll and reshape, as a fraction of the frame.
@export_range(0.0, 0.12) var storm_strength := 0.055
## Speed of the independent billowing currents. Zero freezes the storm.
@export var storm_speed := 1.0
var age := 0.0
var blinking := false
var frame := 0

func _process(delta: float) -> void:
	age += delta
	var interval := maxf(blink_interval, 0.01)
	var duration := clampf(blink_duration, 0.001, interval)
	var blink_time := fmod(age, interval) - (interval - duration)
	blinking = blink_time >= 0.0
	frame = 0
	if blinking:
		var progress := blink_time / duration
		frame = 2 if progress >= 0.25 and progress < 0.75 else 1
	if material is ShaderMaterial:
		material.set_shader_parameter("storm_time", age * storm_speed)
		material.set_shader_parameter("storm_strength", storm_strength)
		material.set_shader_parameter("sheet_frame", float(frame))
		material.set_shader_parameter("pixel_size", draw_size)
	queue_redraw()

func _draw() -> void:
	var bob := roundf(sin(age * 1.7) * float_amplitude)
	var destination := Rect2(Vector2(-draw_size * 0.5, -draw_size * 5.0 / 6.0 + bob), Vector2.ONE * draw_size)
	var source := Rect2(Vector2(frame * FRAME_SIZE.x, 0), FRAME_SIZE)
	draw_texture_rect_region(SHEET, destination, source)
