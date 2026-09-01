extends Node
## Dev capture harness for the talking portraits — not a pass/fail test.
## Photographs the dialogue banner on every frame of a face's loop, so the rig
## can be LOOKED at rather than only asserted on.
## Runs WINDOWED, like tests/room_shot.gd: 2D does not rasterise headless.
##
## Usage: Godot --path . res://tests/portrait_shot.tscn -- hooshang_skeptical
##        Godot --path . res://tests/portrait_shot.tscn -- hooshang_dazed /tmp/shots
##
## Shots go to `user://portrait_shots` unless a directory is given as the second
## argument, and the absolute path is printed. It used to be a hardcoded path
## into one session's scratchpad, which stopped existing the moment that session
## did — a capture harness that writes nowhere is indistinguishable from one that
## silently captured nothing.

const DEFAULT_OUT := "user://portrait_shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var face := "hooshang_skeptical"
	var out := DEFAULT_OUT
	if args.size() > 0:
		face = args[0]
	if args.size() > 1:
		out = args[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) \
		if out.begins_with("user://") else out)

	var box: DialogueBox = Dialogue
	var tex: Texture2D = load("res://assets/portraits/%s.png" % face)
	if tex == null:
		print("no portrait at res://assets/portraits/%s.png" % face)
		get_tree().quit(1)
		return
	box.say("Hooshang", "This doesn't feel like my cubicle.", Color(1, 1, 1, 1), tex,
		DialogueBox.Side.LEFT, DialogueBox.VSide.TOP)
	# Past say()'s own float-in, or every shot below is grabbed mid-entrance,
	# squashed toward zero height rather than at its resting frame.
	for i in int(maxf(box.entrance_time, box.portrait_entrance_time) * 60.0) + 4:
		await get_tree().process_frame

	var dir := ProjectSettings.globalize_path(out) if out.begins_with("user://") else out
	var shots := 0
	if not box._loop.is_empty():
		# Labelled by ROLE, not just by index: the whole question this harness
		# answers is whether the frame the box calls "rest" really is a closed
		# mouth and the one it calls "blink" really is shut eyes.
		var rest := int(box._loop.get("rest", 0))
		var blink := int(box._loop.get("blink", -1))
		for i in int(box._loop.get("frames", 0)):
			var role := "talk"
			if i == rest:
				role = "rest"
			elif i == blink:
				role = "blink"
			box._show_frame(box.portrait_loop, i)
			await _grab("%s/shot_%s_%02d_%s.png" % [dir, face, i, role])
			shots += 1
	elif not box._rig.is_empty():
		# The older overlay rig, kept for any face that still uses one.
		for m in int(box._rig["mouth"]["frames"]):
			box._show_frame(box.portrait_mouth, m)
			box._show_frame(box.portrait_eyes, 0)
			await _grab("%s/shot_%s_mouth%d.png" % [dir, face, m])
			shots += 1
		for e in int(box._rig["eyes"]["frames"]):
			box._show_frame(box.portrait_mouth, 0)
			box._show_frame(box.portrait_eyes, e)
			await _grab("%s/shot_%s_eyes%d.png" % [dir, face, e])
			shots += 1
	else:
		print("%s has neither a loop nor a rig — nothing to photograph" % face)
	print("wrote %d shots for %s into %s" % [shots, face, dir])
	get_tree().quit()


func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
