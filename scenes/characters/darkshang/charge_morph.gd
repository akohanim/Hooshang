@tool
extends Node2D
## The supplied eight poses blend as a single gathering cloud, then release.
const SHEET := preload("res://assets/characters/darkshang/cloud_to_humanoid.png")
const MORPH_SHADER := preload("res://scenes/characters/darkshang/charge_morph.gdshader")
var frame := 0
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		frame = mini(7, int(progress * 8.0))
		if material is ShaderMaterial:
			material.set_shader_parameter("progress", progress)
		queue_redraw()

func _ready() -> void:
	var ink := ShaderMaterial.new()
	ink.shader = MORPH_SHADER
	material = ink
	ink.set_shader_parameter("progress", progress)

func _draw() -> void:
	# Broad inhalation, then a tightening silhouette; the feet remain anchored.
	var settle := smoothstep(0.12, 0.94, progress)
	var inhale := sin(clampf(progress / 0.4, 0.0, 1.0) * PI) * 3.0
	var width := lerpf(72.0, 48.0, settle) + inhale
	var height := lerpf(72.0, 48.0, settle) - inhale * 0.45
	var bottom := lerpf(12.0, 0.0, settle)
	draw_texture_rect(SHEET, Rect2(-width/2, bottom-height, width, height), false)
