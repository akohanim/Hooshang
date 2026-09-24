extends Node
## Act-one-only dressing. Curated mounting rectangles, seeded design shuffle.
## Lives in the wrapper scene so an LDtk reimport never erases the decoration.
const POSTER = preload("res://scenes/props/backdrop/office_posters/OfficePoster.tscn")
const POSTER_ART = preload("res://scenes/props/backdrop/office_posters/office_poster.gd")
## Fixed seed gives an irregular distribution that survives deaths and reloads.
@export var scatter_seed := 180926
## Paper reflectance: brighter than the wall so small lettering remains legible.
@export_range(0.0, 1.0) var paper_brightness := 0.45
## Room-local wall/pillar rectangles, authored against actual rendered rooms.
@export var mounts: Dictionary[String, Array] = {}

func _ready() -> void:
	get_parent().ready.connect(_dress_rooms, CONNECT_ONE_SHOT)

func _dress_rooms() -> void:
	var world := get_parent() as LdtkWorld
	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed
	var portraits: Array[int] = []
	var banners: Array[int] = []
	for room in world.rooms.slice(0, 10):
		if not mounts.has(str(room.name)) or room.has_node("OfficePosters"):
			continue
		var dressing := Node2D.new()
		dressing.name = "OfficePosters"
		dressing.z_index = -1
		# Paper catches more light than the dark wall; ordinary room lighting stays.
		dressing.modulate = Color(paper_brightness, paper_brightness, paper_brightness, 1.0)
		room.add_child(dressing)
		var previous_design := -1
		for mount: Rect2 in mounts[str(room.name)]:
			var wide := mount.size.y <= 24
			var bag: Array[int] = banners if wide else portraits
			if bag.is_empty():
				bag.assign([6, 7] if wide else [0, 1, 2, 3, 4, 5, 8])
				for i in range(bag.size() - 1, 0, -1):
					var j := rng.randi_range(0, i)
					var swap := bag[i]
					bag[i] = bag[j]
					bag[j] = swap
			var poster := POSTER.instantiate()
			var selected := -1
			for i in range(bag.size() - 1, -1, -1):
				if bag.size() > 1 and bag[i] == previous_design:
					continue
				if POSTER_ART.MIN_WIDTH[bag[i]] <= mount.size.x:
					selected = bag[i]
					bag.remove_at(i)
					break
			if selected == -1:
				# A narrow pier can reuse a short slogan without shrinking its type
				# or consuming a wide design waiting for the next broad wall.
				selected = 2 if previous_design == 0 else 0
			poster.design = selected
			previous_design = selected
			poster.name = "Poster_%02d" % dressing.get_child_count()
			poster.position = mount.position
			poster.paper_size = mount.size
			# Mounting varies independently without rerolling the slogan bag.
			poster.paper_style = 2 if wide else (int(mount.position.x) + int(mount.position.y) + selected) % 4
			if selected == 1: poster.paper_style = 0
			var tint: Color = world.room_backdrop_tints.get(str(room.name), Color.WHITE)
			poster.modulate = tint.lerp(Color.WHITE, 0.4)
			dressing.add_child(poster)
