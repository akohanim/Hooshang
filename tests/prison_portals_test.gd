extends Node
var failures := 0
func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	SaveGame.unbind()
	var world = load("res://ldtk/Act2World.tscn").instantiate()
	world.debug_start_room = "Prison_Hub"
	add_child(world)
	await frames(12)
	world.collected.assign(world.IDS)
	world.inserted.assign(world.IDS)
	world.rescued = true
	world.rescue_started = true
	world._refresh()
	for portal in world.portals:
		world._enter_room(portal.from,true)
		world.player.respawn(world.spawn_point_for(portal.from))
		world._portal_cooldown = 0.0
		await frames(4)
		# Set up just outside the strip, then cross its boundary. Destination and
		# safe landing are resolved exclusively by the mission's physics callback.
		world.player.global_position = portal.center-portal.direction*16
		await frames(1)
		world.player.global_position = portal.center
		world.player.velocity = Vector2.ZERO
		await frames(65)
		check(world.current_room == portal.to,"crossing %s -> %s" % [portal.from.name,portal.to.name])
		check(world.room_rect(portal.to).encloses(world.player.hitbox_rect()),"arrival body clear of world boundary")
		await frames(45)
		check(world.current_room == portal.to,"idle must not bounce through return")
		world.player.die()
		await frames(90)
		check(world.current_room == portal.to and world.player.state != Player.State.DEAD,"death keeps destination checkpoint")
	world.queue_free()
	await frames(3)
	print("PRISON PORTALS: 40 crossings/idle/death checks; ",failures," failures")
	get_tree().quit(1 if failures else 0)
