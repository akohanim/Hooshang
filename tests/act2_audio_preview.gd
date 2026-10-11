extends Node
## Audition actual scene voices at gameplay speed; not a complete gameplay mix.
func _ready() -> void:
	var recording := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0,recording)
	recording.set_recording_active(true)
	var cues = load("res://scenes/props/act2_audio/Act2Audio.tscn").instantiate()
	add_child(cues)
	await get_tree().create_timer(.2).timeout
	for cue in ["Key","Lock","Lock","Lock","Lock","Gate","Splash","Spray"]:
		cues.play_cue(StringName(cue))
		await get_tree().create_timer(cues.get_node(cue).stream.get_length()+.18).timeout
	recording.set_recording_active(false)
	var stream := recording.get_recording()
	DirAccess.make_dir_recursive_absolute("res://output/act2_polish/audio_feedback")
	var result := stream.save_to_wav("res://output/act2_polish/audio_feedback/cues.wav")
	print("AUDIO PREVIEW ",result," bytes=",stream.data.size())
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	get_tree().quit(result)
