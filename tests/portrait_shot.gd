extends Node
## Dev capture harness for the talking portraits — not a pass/fail test.
## Photographs the dialogue banner with the mouth at each of its positions and
## the eyes mid-blink, so the rig can be LOOKED at rather than only asserted on.
## Runs WINDOWED, like tests/room_shot.gd: 2D does not rasterise headless.
## Usage: Godot --path . res://tests/portrait_shot.tscn -- hooshang_skeptical

const OUT := "/private/tmp/claude-501/-Users-ari-Hooshang-claude/bcc406e9-2b96-4a9c-85eb-b5f29e4e2f6e/scratchpad"


func _ready() -> void:
	var face := "hooshang_skeptical"
	for arg in OS.get_cmdline_user_args():
		face = arg
	var box: DialogueBox = Dialogue
	var tex: Texture2D = load("res://assets/portraits/%s.png" % face)
	box.say("Hooshang", "This doesn't feel like my cubicle.", Color(1, 1, 1, 1), tex,
		DialogueBox.Side.LEFT, DialogueBox.VSide.TOP)
	for i in 4:
		await get_tree().process_frame

	var shots := 0
	for m in box._rig["mouth"]["frames"]:
		box._show_frame(box.portrait_mouth, m)
		box._show_frame(box.portrait_eyes, 0)
		await _grab("%s/shot_%s_mouth%d.png" % [OUT, face, m])
		shots += 1
	for e in box._rig["eyes"]["frames"]:
		box._show_frame(box.portrait_mouth, 0)
		box._show_frame(box.portrait_eyes, e)
		await _grab("%s/shot_%s_eyes%d.png" % [OUT, face, e])
		shots += 1
	print("wrote %d shots for %s" % [shots, face])
	get_tree().quit()


func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
