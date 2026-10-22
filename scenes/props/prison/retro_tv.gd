class_name RetroTV
extends Node2D
## Hooshang's old console, hooked up to a box TV in the prison hub. The TV
## shows HOOSHANG 64's title screen live from across the room; walk up to it
## and press Up to play.
##
## Playing is a camera move, not a scene change: a Camera2D takes over from
## the player's at exactly what the screen is showing, pushes in until the
## TV's 32x24 screen fills the view, and only THEN hands the picture to a
## full-window overlay that shows the game's own 160x120 viewport with every
## game pixel a whole number of WINDOW pixels (crisp, with a CRT scanline
## pass; see picture_rect). Leaving (Esc/Start, or a game's own `finished`)
## runs the same move backwards.
##
## The same prop is the hub's OTHER machine too: set `art`, `screen` and `game`
## before adding it (PrisonWorld._add_minigames puts the old PC running
## SIMORGH on the stage across the hall). A game only has to be 160x120 and
## answer activate()/deactivate() with exit_requested/finished signals.
##
## Origin: the prop's bottom-left, standing on the floor. Art: tools/gen_retro_tv.py.

const ART := preload("res://assets/props/retro_tv/tv.png")
const FONT := preload("res://assets/fonts/pixel5x7.fnt")
## The screen well inside tv.png (tools/gen_retro_tv.py).
const SCREEN := Rect2(8, 17, 32, 24)
const PUSH_TIME := 1.3
## How close (px, horizontally from the TV's middle) counts as "at the TV".
const REACH := 22.0

var world: Node
## Which machine: its art, the live screen's rect inside that art, and the game
## it runs (RetroGame, HOOSHANG 64, when left null).
var art: Texture2D = ART
var screen := SCREEN
var game: Node2D
var _viewport: SubViewport
var _screen: Sprite2D
var _cam: Camera2D
var _overlay: CanvasLayer
var _picture: TextureRect
var _crt: ColorRect
var _playing := false
var _busy := false
## A game may finish with an in-world reward sequence after the pull-out.
var completion_callback: Callable


func _ready() -> void:
	var body := Sprite2D.new()
	body.texture = art
	body.centered = false
	body.position = Vector2(0, -art.get_height())
	add_child(body)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(RetroGame.W, RetroGame.H)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.audio_listener_enable_2d = false
	add_child(_viewport)
	if game == null: game = RetroGame.new()
	_viewport.add_child(game)
	game.exit_requested.connect(_leave)
	game.finished.connect(_finish_game)
	_screen = Sprite2D.new()
	_screen.texture = _viewport.get_texture()
	_screen.centered = false
	_screen.position = body.position + screen.position
	_screen.scale = screen.size / Vector2(RetroGame.W, RetroGame.H)
	# A lit screen in a dark hall: unshaded, so the room's lighting never dims it.
	var lit := CanvasItemMaterial.new()
	lit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_screen.material = lit
	add_child(_screen)
	# The imported hub wall art is on the default canvas layer. A negative z
	# hid both machines behind it. At zero they draw after the room, while the
	# player remains in front when he stands at the screen.
	z_index = 0


func screen_center() -> Vector2:
	return global_position + Vector2(0, -art.get_height()) + screen.get_center()


func _near() -> bool:
	if world == null or world.player == null: return false
	var p: Player = world.player
	var mid := global_position.x + screen.get_center().x
	return absf(p.global_position.x - mid) <= REACH and absf(p.global_position.y - (global_position.y - 6.0)) < 10.0


func _physics_process(_delta: float) -> void:
	queue_redraw()
	if _playing or _busy or world == null: return
	var p: Player = world.player
	if p == null or p.input_locked or p.state == Player.State.DEAD: return
	if _near() and p.is_on_floor() and Input.is_action_just_pressed("move_up"):
		_play()


func _draw() -> void:
	if _playing or _busy or not _near(): return
	var text := "UP: PLAY"
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	var at := Vector2(screen.get_center().x - w * 0.5, -art.get_height() - 4)
	draw_rect(Rect2(at + Vector2(-2, -7), Vector2(w + 4, 9)), Color(0, 0, 0, 0.6))
	draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("fff2c9"))


## The key that leaves a game, as the device he is using names it — for the
## games' own on-screen hints.
static func leave_key() -> String:
	return "START" if InputDevice.is_controller() else "ESC"


func _play() -> void:
	_busy = true
	var p: Player = world.player
	p.input_locked = true
	p.velocity = Vector2.ZERO
	_cam = Camera2D.new()
	_cam.top_level = true
	add_child(_cam)
	_cam.global_position = p.camera.get_screen_center_position()
	_cam.zoom = p.camera.zoom
	_cam.make_current()
	var zoom := minf(Screen.GAME_SIZE.x / screen.size.x, Screen.GAME_SIZE.y / screen.size.y)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_cam, "global_position", screen_center(), PUSH_TIME)
	tween.tween_property(_cam, "zoom", Vector2(zoom, zoom), PUSH_TIME)
	_duck_music(true)
	await tween.finished
	_show_overlay()
	game.activate()
	_playing = true
	_busy = false


func _finish_game() -> void:
	if not completion_callback.is_valid():
		_leave()
		return
	if not _playing or _busy: return
	await _leave(true)
	await complete_reward()


## Used both after a live clear and when a save reloads mid-payout.
func complete_reward() -> void:
	if _busy or world == null or world.player == null: return
	_busy = true
	world.player.input_locked = true
	await completion_callback.call(self)
	if not is_inside_tree(): return
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.55)
	await fade.finished
	world.player.input_locked = false
	_busy = false
	queue_free()


func _leave(keep_locked := false) -> void:
	if not _playing or _busy: return
	_busy = true
	_playing = false
	game.deactivate()
	_hide_overlay()
	if keep_locked:
		# Leave a dark screen behind the bright fruit exiting it.
		_screen.modulate = Color(0.22, 0.18, 0.3)
	var p: Player = world.player
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_cam, "global_position", p.camera.get_screen_center_position(), PUSH_TIME * 0.8)
	tween.tween_property(_cam, "zoom", p.camera.zoom, PUSH_TIME * 0.8)
	await tween.finished
	p.camera.make_current()
	_cam.queue_free()
	_duck_music(false)
	if not keep_locked:
		p.input_locked = false
	_busy = false


## Full-window presentation once the push-in has filled the view with the
## screen: the game's 160x120, as large as picture_rect allows, under a CRT
## scanline pass. Laid out again whenever the window changes size.
func _show_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 105
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = Vector2(Screen.GAME_SIZE)
	_overlay.add_child(black)
	_picture = TextureRect.new()
	_picture.texture = _viewport.get_texture()
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	# Without this a TextureRect is never smaller than its texture.
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_overlay.add_child(_picture)
	_crt = ColorRect.new()
	_crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scenes/props/prison/crt.gdshader")
	_crt.material = mat
	_overlay.add_child(_crt)
	get_tree().root.add_child(_overlay)
	get_tree().root.size_changed.connect(_layout_overlay)
	_layout_overlay()


func _layout_overlay() -> void:
	if _overlay == null: return
	var rect := picture_rect(get_tree().root.get_final_transform().get_scale().x)
	for c: Control in [_picture, _crt]:
		c.position = rect.position
		c.size = rect.size


## Where the game picture goes in the 320x180 design space when the window
## stretches that space by `scale`: the largest size at which every game pixel
## is the same WHOLE number of window pixels, centred on a whole window pixel.
## A fixed 1.5x (240x180) only managed that at even stretch factors — at x9 (a
## 2880x1800 screen, or a 960x540 window on Retina) game pixels came out 13
## and 14 window pixels wide by turns.
static func picture_rect(scale: float) -> Rect2:
	var k := maxf(roundf(scale), 1.0)
	var pic := Vector2(RetroGame.W, RetroGame.H)
	var whole := floorf(minf(Screen.GAME_SIZE.x * k / pic.x, Screen.GAME_SIZE.y * k / pic.y))
	var at := ((Vector2(Screen.GAME_SIZE) * k - pic * whole) * 0.5).floor()
	return Rect2(at / k, pic * whole / k)


func _hide_overlay() -> void:
	if _overlay != null:
		get_tree().root.size_changed.disconnect(_layout_overlay)
		_overlay.queue_free()
		_overlay = null


func _duck_music(on: bool) -> void:
	var bus := AudioServer.get_bus_index(&"Music")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, -18.0 if on else 0.0)
