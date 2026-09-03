extends Node
## Unit test for HooshangDialogueAnimator: verifies matrix frames, blinks, and dialogue playback.

var failures: Array[String] = []

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  PASS  %s" % description)
	else:
		print("  FAIL  %s" % description)
		failures.append(description)

func _ready() -> void:
	print("--- Running HooshangDialogueAnimator Tests ---")
	var animator := HooshangDialogueAnimator.new()
	animator.size = Vector2(256, 256)
	add_child(animator)

	# 1. Texture Loading
	_check(animator._matrix_textures.size() == 5, "All 5 primary emotions loaded into texture dictionary")
	for emo in ["neutral", "happy", "angry", "sad", "surprised"]:
		var frames: Array = animator._matrix_textures.get(emo, [])
		var valid_count := 0
		for tex in frames:
			if tex is Texture2D and tex.get_width() > 0:
				valid_count += 1
		_check(valid_count == 9, "%s has 9 valid non-empty textures [found %d/9]" % [emo, valid_count])

	# 2. Expression Resolution & Aliases
	_check(animator.resolve_emotion("HAPPY") == "happy", "Uppercase emotion resolves to happy")
	_check(animator.resolve_emotion("hooshang_annoyed") == "angry", "Legacy hooshang_annoyed aliases to angry")
	_check(animator.resolve_emotion("dazed") == "sad", "Legacy dazed aliases to sad")
	_check(animator.resolve_emotion("shocked") == "surprised", "Legacy shocked aliases to surprised")

	# 3. play_expression & Frame Index Calculation
	animator.play_expression("happy")
	_check(animator.current_emotion == "happy", "play_expression('happy') sets current_emotion")
	_check(animator.mouth_state == HooshangDialogueAnimator.MouthState.CLOSED, "Initial mouth state is CLOSED")
	_check(animator.eye_state == HooshangDialogueAnimator.EyeState.OPEN, "Initial eye state is OPEN")
	_check(animator.texture_display != null and animator.texture_display.texture != null, "TextureDisplay shows active frame")

	# 4. Blink Cycle
	# Force blink phase 1
	animator._blink_timer = 0.0
	animator._process_blinking(0.01)
	_check(animator.eye_state == HooshangDialogueAnimator.EyeState.MID_BLINK, "Blink starts with MID_BLINK")
	animator._process_blinking(0.05)
	_check(animator.eye_state == HooshangDialogueAnimator.EyeState.CLOSED, "Blink transitions to CLOSED")
	animator._process_blinking(0.07)
	_check(animator.eye_state == HooshangDialogueAnimator.EyeState.MID_BLINK, "Blink transitions back to MID_BLINK")
	animator._process_blinking(0.05)
	_check(animator.eye_state == HooshangDialogueAnimator.EyeState.OPEN, "Blink finishes with OPEN")

	# 5. Dialogue Mouth Sync
	animator.play_dialogue("Test dialogue line", "angry", 0.05)
	_check(animator.is_talking, "play_dialogue sets is_talking to true")
	_check(animator.current_emotion == "angry", "play_dialogue updates emotion to angry")

	# Advance talk timer
	animator._talk_timer = 0.0
	animator._process_talking(0.01)
	_check(animator.mouth_state != HooshangDialogueAnimator.MouthState.CLOSED, "Talking mouth is open (not closed)")

	animator.set_talking(false)
	_check(animator.mouth_state == HooshangDialogueAnimator.MouthState.CLOSED, "Stopping talking returns mouth to CLOSED")

	# Test DialogueBox integration
	var box: DialogueBox = Dialogue
	_check(box != null, "DialogueBox autoload exists")
	_check(box.has_method("play_hooshang_expression"), "DialogueBox has play_hooshang_expression method")
	_check(box.has_method("show_portrait"), "DialogueBox has show_portrait method")

	if failures.is_empty():
		print("HOOSHANG ANIMATOR TEST: ALL PASS")
		get_tree().quit(0)
	else:
		print("HOOSHANG ANIMATOR TEST: %d FAILURES" % failures.size())
		get_tree().quit(1)
