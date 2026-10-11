extends Node
## Audit the imported rooms AND authored finale; cached rooms must inherit the shared art.
var count := 0
var failures: Array[String] = []
const FRAMES := preload("res://assets/characters/jamshid/jamshid_frames.tres")
func _ready() -> void:
	var packed: Node = load("res://ldtk/Act2World.tscn").instantiate()
	scan(packed)
	check(count >= 18, "Act 2 placements and finale were traversed")
	var salute := packed.get_node("Act2Ending/Cinema/Stage/Flight/Salute") as Sprite2D
	check(salute.texture.resource_path == "res://assets/characters/jamshid/act2_ending/half_salute_child.png", "finale uses child salute")
	check(salute.texture.get_size() == Vector2(88,88), "salute child canvas")
	check(salute.scale == Vector2.ONE * 0.375 and salute.centered and salute.offset == Vector2(0,-19), "salute matches child scale and floor anchor")
	check(salute.material == null, "no legacy painted-art alpha shader")
	if "--capture" in OS.get_cmdline_user_args():
		var flight: Node2D = packed.get_node("Act2Ending/Cinema/Stage/Flight")
		flight.get_parent().remove_child(flight)
		clear_owners(flight)
		var world := Node2D.new()
		Screen.set_scene(world)
		var bg := Polygon2D.new()
		bg.polygon = PackedVector2Array([Vector2.ZERO,Vector2(320,0),Vector2(320,180),Vector2(0,180)])
		bg.color = Color("455455")
		world.add_child(bg)
		world.add_child(flight)
		flight.position = Vector2(160,90)
		flight.get_node("Jamshid").hide()
		salute.show()
		await RenderingServer.frame_post_draw
		var im := Screen.viewport.get_texture().get_image()
		im.save_png("res://output/jamshid_pair/salute_gameplay_native.png")
		im.resize(1280,720,Image.INTERPOLATE_NEAREST)
		im.save_png("res://output/jamshid_pair/salute_gameplay.png")
	packed.free()
	print("ACT2 JAMSHID ART: ",count," actors; ", "ALL PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
func scan(n: Node) -> void:
	if n is Jamshid:
		count += 1
		var visual := n.get_node("Visual") as AnimatedSprite2D
		check(visual.sprite_frames == FRAMES, str(n.name)+" uses approved shared frames")
		check(is_equal_approx(n.standing_height,15.0), str(n.name)+" uses child height")
		check(visual.centered and visual.offset == Vector2(0,-3), str(n.name)+" uses child anchor")
		check(n.has_node("SockPixels"), str(n.name)+" keeps native sock marks")
	if n is JamshidNpc: check(is_equal_approx(n.standing_height,15.0), "NPC does not override height")
	for child in n.get_children(): scan(child)
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func clear_owners(node: Node) -> void:
	node.owner = null
	for child in node.get_children(): clear_owners(child)
