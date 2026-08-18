extends Node
## PROTOTYPE — can a lemon token be drawn at higher pixel density than the
## room it sits in? Throwaway; wired into nothing.
##
## THE PROBLEM. The world renders into a 320x180 SubViewport and is then
## integer-upscaled, so every object in it — whatever node type, whatever layer,
## Parallax2D included — is resampled to that grid. Density is a property of the
## RENDER TARGET, not of the node.
##
## THE IDEA UNDER TEST. A second SubViewport at 2x (640x360), transparent, with
## its own Camera2D locked to the world camera at zoom 2 so it frames exactly the
## same world rectangle. Composite it over the game view at the same on-screen
## rect. A token drawn there occupies the same number of SCREEN pixels but is cut
## from twice as many texels.
##
## WHY A TOKEN IS THE EASY CASE. The two objections to a high-density layer are
## camera sync and lighting. Lighting barely applies here: a collectible is meant
## to stand out, so a token that ignores the room's darkness and stays bright is
## arguably the wanted behaviour rather than the bug it would be for scenery.
## That leaves sync, which this measures directly — the camera is walked across
## the room and the two fruit are compared at each stop.
##
## TO LOOK AT IT: run the project (F5) and press "Token density (2x)" in the
## debug picker. Arrow keys / WASD pan the camera — walk it about and watch
## whether the token swims against the wall behind it, which is the one thing
## this arrangement can get wrong. P saves a screenshot to /tmp. Escape goes
## back to the picker.
##
## Its layers go on the WINDOW's surface, not inside this node: the picker hands
## scenes to Screen.load_scene(), which drops them in the 320x180 game viewport —
## and a high-density layer rendered inside the low-density one is just the
## low-density one.

const GAME := Vector2i(320, 180)
## How many times denser the token layer is. 2 keeps every ratio a whole number,
## which is what stops the composite resampling and undoing the whole exercise.
const DENSITY := 2
const WINDOW_SCALE := 4          # game px -> window px, as the real game runs

const NORMAL_TEX := preload("res://assets/props/lemon/frame_000.png")
const DENSE_TEX := preload("res://assets/props/lemon/dense/frame_000.png")

var world_cam: Camera2D
var token_cam: Camera2D
var _front: CanvasLayer
var _tokens: SubViewport
var _world: SubViewport
var _at := Vector2(160, 90)


## The probe's layers live on the window root, so they have to be taken down by
## hand — leaving them up would paint over the picker on the way back.
func _exit_tree() -> void:
	if is_instance_valid(_front):
		_front.queue_free()


func _ready() -> void:
	get_window().size = GAME * WINDOW_SCALE
	# On a layer of our own, in FRONT of everything. The Screen autoload owns the
	# window's surfaces and paints its own black backdrop over the root; a first
	# run of this captured nothing but the two HUD counters on black, because
	# both containers below were behind it. Nothing here goes through Screen on
	# purpose — the whole question is what happens OUTSIDE the 320x180 surface it
	# manages.
	# Built now, ATTACHED at the end of the frame. Adding to the window root
	# during _ready fails outright — the root is mid-way through setting up the
	# scene Screen just handed it ("Parent node is busy setting up children") —
	# and the failure is silent enough to look like a rendering problem.
	var front := CanvasLayer.new()
	front.name = "TokenDensityProbe"
	front.layer = 100
	_front = front

	# --- the world, exactly as the game renders it -------------------------
	# Sized in the DESIGN space (320x180), exactly as systems/screen.gd sizes its
	# own. The window's `canvas_items` stretch scales the whole UI up to the
	# window, so a container of 320x180 fills the screen — and `stretch = true`
	# keeps the SubViewport matched to it. Sizing it in WINDOW pixels instead was
	# the first mistake here: it silently resized the "320x180" viewport to
	# 1280x720, so the low-density half of the comparison was not low density.
	var world_box := SubViewportContainer.new()
	world_box.stretch = true
	world_box.size = Vector2(GAME)
	front.add_child(world_box)
	var world := SubViewport.new()
	world.size = GAME
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	world_box.add_child(world)
	_world = world

	world.add_child(_room())
	world_cam = Camera2D.new()
	world.add_child(world_cam)
	# The fruit as it ships today: 20px of texture, 20 world units.
	var normal := Sprite2D.new()
	normal.texture = NORMAL_TEX
	normal.position = Vector2(130, 96)
	world.add_child(normal)

	# --- the token layer, at DENSITY x --------------------------------------
	# Displayed through a SubViewportContainer with stretch OFF.
	#
	# stretch=true would drag this viewport back down to the container's size and
	# there would be no extra density left to show — that is what it does, and it
	# is why the world above uses it. stretch=false shows the viewport at its own
	# 640x360, and the container is then scaled to 1/DENSITY so it covers the
	# same 320x180 design rect. The window's canvas_items stretch maps that onto
	# 1280x720, giving two output pixels per texel against the world's four.
	#
	# A plain TextureRect fed by `tokens.get_texture()` was tried first and drew
	# nothing on screen at all, even though the viewport it pointed at provably
	# had the fruit in it. SubViewportContainer is the node that exists for this.
	var tokens := SubViewport.new()
	tokens.size = GAME * DENSITY
	tokens.transparent_bg = true          # so the room shows through
	tokens.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tokens.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST

	var token_box := SubViewportContainer.new()
	token_box.stretch = false
	token_box.size = Vector2(GAME * DENSITY)
	token_box.scale = Vector2.ONE / float(DENSITY)
	token_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.add_child(token_box)
	token_box.add_child(tokens)
	_tokens = tokens

	token_cam = Camera2D.new()
	# Zoom = density, so this viewport frames the SAME world rectangle: 640px of
	# viewport at 2x covers 320 world units, the width the world viewport shows.
	token_cam.zoom = Vector2(DENSITY, DENSITY)
	tokens.add_child(token_cam)
	# 40px of texture at HALF scale, under that 2x zoom, covers 20 world units —
	# the same footprint as the 20px fruit in the world, out of twice as many
	# texels along each axis.
	#
	# The scale is not optional and it is the easy thing to get wrong: Godot's
	# `zoom` scales the DRAWING, not just the framing, so a 40px sprite at zoom 2
	# covers 40 world units. The first capture of this looked like a triumph and
	# was really just a bigger lemon.
	var dense := Sprite2D.new()
	dense.texture = DENSE_TEX
	dense.scale = Vector2.ONE / float(DENSITY)
	dense.position = Vector2(190, 96)
	tokens.add_child(dense)

	# A label per fruit, drawn in the world so it is subject to the same grid.
	world.add_child(_tag("320x180", Vector2(104, 112)))
	world.add_child(_tag("640x360", Vector2(164, 112)))

	get_tree().root.add_child.call_deferred(front)
	await get_tree().process_frame
	await get_tree().process_frame
	_look(_at)
	# Both arrays: Godot routes anything after a bare `--` into
	# get_cmdline_user_args(), and everything it did not consume itself into
	# get_cmdline_args(). Checking only the second one silently never fires.
	if OS.get_cmdline_args().has("--autoshot") \
			or OS.get_cmdline_user_args().has("--autoshot"):
		for f in 20:
			await get_tree().process_frame
		_shoot()
		get_viewport().get_texture().get_image().save_png("/tmp/td_root.png")
		get_tree().quit()


## Pan both cameras together. The whole sync is these two lines — if the token
## ever swims against the wall behind it, it is because these disagreed.
func _look(at: Vector2) -> void:
	_at = at
	world_cam.global_position = at
	token_cam.global_position = at


func _process(delta: float) -> void:
	var pan := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if pan != Vector2.ZERO:
		_look(_at + pan * 90.0 * delta)
	if Input.is_action_just_pressed("respawn"):      # P is not bound; R is
		_shoot()
	if Input.is_action_just_pressed("ui_cancel"):
		Screen.load_scene("res://scenes/debug_level_picker.tscn")


## Both viewports and the composite, for looking at afterwards.
func _shoot() -> void:
	_world.get_texture().get_image().save_png("/tmp/td_world.png")
	_tokens.get_texture().get_image().save_png("/tmp/td_token.png")
	print("saved /tmp/td_world.png and /tmp/td_token.png  camera=%s" % _at)


## Something with hard edges and a tile grid, so any misalignment between the
## two layers has something to be measured against.
func _room() -> Node2D:
	var room := Node2D.new()
	var back := ColorRect.new()
	back.color = Color(0.22, 0.19, 0.22)
	back.size = Vector2(GAME) * 2.0
	back.position = -Vector2(GAME) * 0.5
	room.add_child(back)
	for cx in range(-10, 30):
		for cy in range(-6, 18):
			var cell := ColorRect.new()
			cell.color = Color(0.27, 0.24, 0.28) if (cx + cy) % 2 == 0 \
				else Color(0.24, 0.21, 0.25)
			cell.size = Vector2(15, 15)
			cell.position = Vector2(cx * 16, cy * 16)
			room.add_child(cell)
	return room


func _tag(text: String, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	return label
