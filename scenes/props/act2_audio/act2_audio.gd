extends Node
## Act-local cues; no global bus edits or persistent state.
signal cue_started(cue: StringName)
func play_cue(cue: StringName) -> void:
	var voice := get_node_or_null(NodePath(cue)) as AudioStreamPlayer
	if voice == null: return
	voice.play()
	cue_started.emit(cue)
func stop_cinematics() -> void:
	$Spray.stop()
	$Splash.stop()
