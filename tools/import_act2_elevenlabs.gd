extends SceneTree
## Pack the mastered WAVs as native resources without an editor re-import.
func _init() -> void:
	for cue in ["key", "lock", "gate", "splash", "spray"]:
		var base: String = "res://assets/audio/act2_elevenlabs/" + cue
		var stream := AudioStreamWAV.load_from_file(base + ".wav")
		if stream == null or ResourceSaver.save(stream, base + ".res") != OK:
			push_error("Could not pack Act II cue: " + cue)
			quit(1)
			return
	print("Packed five ElevenLabs Act II cues.")
	quit()
