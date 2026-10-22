extends Node
## Real threaded loading, ordered text, paused gameplay, menu routing and UI
## isolation. Optional --capture saves the three rendered reveal stages.

const PROBE := "res://tests/loading_probe.tscn"
var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  PASS " if ok else "  FAIL ") + message)
	if not ok:
		failures += 1


func _ready() -> void:
	SaveGame.unbind()
	var before := Screen.load_scene(PROBE)
	await frames(5)
	var ticks: int = before.ticks
	Screen.load_scene_with_card(PROBE)
	await frames(2)
	var card := Screen.loading_card
	check(Screen.loading and card != null, "a whole-world load shows the lemon card")
	check(get_tree().paused and Screen.current == before, "old gameplay waits while loading and reading")
	card.set_process(false)
	await frames(5)
	check(before.ticks == ticks, "the covered world does not tick")
	check(not Screen.viewport.is_ancestor_of(card) and card.layer > 130, "watercolor draws at UI resolution above film/fades")
	check(Screen.viewport.size == Vector2i(320, 180) and Screen.viewport.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST, "world pixel resolution/filter stay intact")
	check(card.root.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "watercolor uses its own smooth UI sampling")
	check(card.first.text.replace("\n", " ") == "WHEN LIFE GIVES YOU A LEMON", "first phrase matches the poster")
	check(card.second.text.replace("\n", " ") == "YOU MUST EAT THE LEMON", "second phrase is the instruction")
	check(card.third.text.replace("\n", " ") == "ALL OF IT INCLUDING THE SKIN", "third phrase contains the final words")
	check(card.third.get_theme_font_size("font_size") < card.second.get_theme_font_size("font_size"), "last phrase is smaller")
	check(card.first.get_theme_font("font").resource_path.ends_with("PatrickHand-Regular.ttf"), "lettering uses the handwritten font")
	check(card.get_node("Root/Paper").texture.resource_path.ends_with("lemon_watercolor_leaf.png"), "selected watercolor retains the leaf")
	card.set_elapsed(0.0)
	check(card.first.modulate.a == 0 and card.second.modulate.a == 0 and card.third.modulate.a == 0, "text starts hidden")
	card.set_elapsed(card.first_delay + card.reveal_time)
	check(is_equal_approx(card.first.modulate.a, 1.0) and card.second.modulate.a == 0 and card.third.modulate.a == 0, "upper-left phrase arrives first")
	await shot("01_first")
	card.set_elapsed(card.second_delay + card.reveal_time)
	check(is_equal_approx(card.first.modulate.a, 1.0) and is_equal_approx(card.second.modulate.a, 1.0) and card.third.modulate.a == 0, "lower-right instruction follows, keeping the first phrase")
	await shot("02_second")
	card.set_elapsed(card.third_delay + card.reveal_time)
	check(is_equal_approx(card.third.modulate.a, 1.0) and not card.readable, "small final thought appears before the reading hold ends")
	await shot("03_complete")
	var same := card
	Screen.load_scene_with_card(PROBE)
	check(Screen.loading_card == same, "repeated requests do not stack loading cards")
	var paused_at_ready := [false]
	var on_load := func(scene: Node) -> void:
		paused_at_ready[0] = get_tree().paused and scene.ticks == 0
	Screen.scene_loaded.connect(on_load, CONNECT_ONE_SHOT)
	Engine.time_scale = 0.3
	card.set_elapsed(card.reading_time)
	await wait_loading()
	check(not Screen.loading and Screen.loading_card == null and not get_tree().paused, "completion removes the card and restores the pause state")
	check(paused_at_ready[0], "new gameplay is held beneath the final fade")
	check(is_equal_approx(Engine.time_scale, 0.3), "loading preserves the world's time scale")
	Engine.time_scale = 1.0
	await frames(5)
	check(Screen.current != before and Screen.current.ticks > 0, "loaded world starts normally after the card")
	var keep := Screen.current
	await Screen.load_scene_with_card("res://missing_loading_scene.tscn")
	check(Screen.current == keep and not Screen.loading and not get_tree().paused, "failed request keeps the previous world and unlocks loading")
	# Use an actual chapter-browser row, not a test-only load path.
	var menu := load("res://scenes/ui/MainMenu.tscn").instantiate() as MainMenu
	add_child(menu)
	menu._show_explore(2)
	for i in menu._catalog[2].size():
		if str(menu._catalog[2][i].id) == "Act3_Level_30":
			menu.selected = i
			break
	menu.choose()
	check(Screen.loading and Screen.loading_card != null, "chapter-browser play uses the watercolor card")
	if Screen.loading_card != null:
		Screen.loading_card.set_elapsed(Screen.loading_card.reading_time)
	await wait_loading()
	await frames(20)
	check(Screen.current is SeaWorld and str(Screen.current.current_room.name) == "Act3_Level_30", "chapter choice survives the background load")
	check(SaveGame.slot == -1, "exploration loading writes no save")
	print("LEMON LOADING: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func wait_loading() -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while Screen.loading and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(not Screen.loading, "loading finishes within its timeout")


func shot(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/lemon_loading/%s.png" % label)


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
