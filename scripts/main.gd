extends Node2D

@onready var _player : CharacterBody2D = $Player
@onready var _camera : Camera2D        = $Camera2D


func _ready() -> void:
	_camera.call("configure_limits", -2000, -2000, 2000, 500)
	_camera.global_position = _player.global_position
	_camera.set("target", _player)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
 
