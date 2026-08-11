extends Node2D
## Runtime launcher for the LDtk-authored Level_1_Office: instances the
## LDtk-generated scene as a plain child (no editing of the generated .scn
## itself — that stays a pure re-generatable artifact, see STYLE_GUIDE.md §9)
## and spawns the real player at its "PlayerStart" marker at runtime.
##
## Spawning here (at play time) rather than via a level_post_import hook is
## deliberate: the ldtk-importer plugin's own save step re-parents ownership
## of everything under a level when it packs it to disk, which double-bakes
## nested scene instances (like the player, which has its own children) into
## the saved file. Keeping the spawn at runtime sidesteps that entirely.

const LEVEL_SCENE := preload("res://ldtk/levels/Level_0.scn")
const PLAYER_SCENE := preload("res://scenes/characters/hooshang/Hooshang.tscn")


func _ready() -> void:
	var level: Node2D = LEVEL_SCENE.instantiate()
	add_child(level)
	var spawn := level.get_node_or_null("Entities/PlayerStart")
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = spawn.global_position if spawn else Vector2.ZERO
