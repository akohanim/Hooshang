class_name Act2Beats
extends Node
## Act 2's scripted story beats. Right now that is one encounter: Hooshang swims
## across the pond in Act_2_Level_1 and finds his cousin Jamshid fishing on the
## far bank. They talk, Jamshid hooks a fish, the sun sets, he builds a fire, and
## the two of them talk the whole night through — Hooshang recounting the dream
## that WAS Act 1 — until dawn, when Jamshid rushes off to school on a passing magic carpet.
##
## Same shape as scripts/act1_beats.gd: this lives as a child of the world scene
## (ldtk/Act2World.tscn), waits for LdtkWorld to instantiate its rooms, then
## CLAIMS the encounter by finding Level_1's JamshidNpc, setting its
## `defer_to_cutscene` and connecting its `triggered` signal here — so walking
## up to Jamshid stages this beat instead of his one-line greeting. The
## environment (a CanvasModulate for the time of day, a StarField for the night)
## is driven from here too, the same way Act1Beats drives the office's collapse
## and blood moon.
##
## Dialogue holds are player-paced; the nine ellipsis reactions and three
## night transitions advance automatically. All cutscene motion stays on the native
## game viewport, with nearest filtering and pixel-snapped transforms.

const HOOSHANG_PALE := Color(1.0, 1.0, 1.0, 1.0)
const JAMSHID_WARM := Color(1.0, 1.0, 1.0, 1.0)  # his portraits are real art — never tinted
const EMOTE_SCENE := preload("res://scenes/ui/EmoteBubble.tscn")
const CAMPFIRE_SCENE := preload("res://scenes/props/Campfire.tscn")
const STAR_FIELD_SCENE := preload("res://scenes/props/backdrop/StarField.tscn")
const CARPET_TEXTURE := preload("res://assets/props/magic_carpet/ride.png")
const CHILD_FRAMES := preload("res://assets/characters/hooshang_child/act2_frames.tres")
## Act 2 is Hooshang's childhood memory, so its dialogue uses the child art.
# Faces are named childhooshang_<state>.png on purpose: DialogueBox derives
# both its portrait-rig key AND its VoiceBlips pool key from the texture's
# basename (see dialogue_box.gd's _voice_key / _set_rig), so this filename is
# what routes a line to the "childhooshang" voice in gen_voice_blips.py — the
# <speaker>_<state> contract every other speaker's portraits follow. The
# speaker token is one run-on word with NO underscore on purpose: VoiceBlips
# splits the key on its FIRST underscore to keep the speaker whole while
# letting a STATE name carry one ("warm_open"), so a speaker with an underscore
# would misroute (see systems/voice_blips.gd's split, and voice_blip_test.gd).
const CHILD_FACES := {
	"neutral": preload("res://assets/characters/hooshang_child/faces/childhooshang_neutral.png"),
	"happy": preload("res://assets/characters/hooshang_child/faces/childhooshang_happy.png"),
	"sad": preload("res://assets/characters/hooshang_child/faces/childhooshang_sad.png"),
	"surprised": preload("res://assets/characters/hooshang_child/faces/childhooshang_surprised.png"),
	"annoyed": preload("res://assets/characters/hooshang_child/faces/childhooshang_annoyed.png"),
	"vulnerable": preload("res://assets/characters/hooshang_child/faces/childhooshang_vulnerable.png"),
}

## Which room the encounter lives in (LDtk level identifier).
@export var room_name := "Act_2_Level_1"

## Times of day, as CanvasModulate colours. DAY is Act2World's own authored tint;
## the rest are where the beat tweens it. Night is kept off true black so the two
## characters still read by the firelight; the campfire's own warm light lifts
## them the rest of the way.
const DAY := Color(0.95, 0.9, 0.78, 1.0)
const SUNSET := Color(1.0, 0.6, 0.42, 1.0)
const NIGHT := Color(0.30, 0.34, 0.52, 1.0)
const DAWN := Color(0.82, 0.72, 0.72, 1.0)

## How high above a character's origin a reaction bubble floats.
@export var emote_height := -18.0

var _world: LdtkWorld
var _canvas_mod: CanvasModulate
var _stars: StarField
var _fade: ColorRect
var _played := false
var _pond_fish: Fish
var _rod: Node2D
var _line: Line2D
var _caught := false
var _speaker: JamshidNpc


func _ready() -> void:
	_world = _find_world()
	if _world == null:
		push_error("Act2Beats: no LdtkWorld ancestor — put this inside the world scene.")
		return
	_canvas_mod = _world.get_node_or_null("CanvasModulate")
	_build_fade()
	_build_stars()
	# Rooms are created in LdtkWorld's own _ready(), which runs AFTER this child's
	# — wait for them rather than looking now and finding nothing (same as
	# Act1Beats).
	for i in 10:
		if not _world.rooms.is_empty():
			break
		await get_tree().process_frame
	# LdtkWorld creates the Player together with its rooms. Apply the childhood
	# sprites only after that setup has finished; doing it earlier finds no player
	# and leaves the adult visuals in the first Act 2 room.
	_apply_child_player_art()
	var room := _find_room(room_name)
	if room == null:
		push_warning("Act2Beats: no room named '%s' — the encounter is disabled." % room_name)
		return
	var jamshid := _find_jamshid(room)
	if jamshid == null:
		push_warning("Act2Beats: no JamshidNpc in '%s' — the encounter is disabled." % room_name)
		return
	# Claim the encounter BEFORE the player can reach him, or his own one-line
	# greeting plays instead of this.
	_speaker = jamshid
	jamshid.actor.play_pose("sit")
	jamshid.actor.face_left(true)
	_rod = _add_fishing_rod(jamshid)
	_prepare_pond_fish(room, jamshid)
	jamshid.defer_to_cutscene = true
	jamshid.triggered.connect(_on_jamshid_reached.bind(jamshid))


## Act 2 is the childhood memory. Keep the Player scene and physics unchanged,
## but swap its visual library before the first room becomes playable.
func _apply_child_player_art() -> void:
	if _world.player == null:
		return
	var visual := _world.player.get_node_or_null("SpriteSquash/Visual") as AnimatedSprite2D
	if visual == null:
		push_warning("Act2Beats: Player has no visual sprite to switch to child Hooshang.")
		return
	visual.sprite_frames = CHILD_FRAMES
	_world.player._update_visual()


func _on_jamshid_reached(_player: Player, jamshid: JamshidNpc) -> void:
	if _played:
		return
	_played = true
	_play_encounter(jamshid)


# ----------------------------------------------------------- the encounter ----

func _play_encounter(jamshid: JamshidNpc) -> void:
	var player := _world.player
	player.input_locked = true
	var actor: Jamshid = jamshid.actor
	# He is fishing: sitting on the bank, facing the water (Hooshang's side).
	actor.play_pose("sit")
	actor.face_left(true)
	var rod := _rod

	player.freeze()
	await _jamshid(jamshid, "Cousin joon!", "excited")
	await _hooshang("Jamshid! It’s so good to see you!", "happy")
	await _jamshid(jamshid, "You saw me yesterday.", "friendly")
	await _hooshang("It feels like so much longer.", "vulnerable")
	await _jamshid(jamshid, "Well, get out of the water. You’re frightening dinner.", "joyful")
	await _tween_arc(player, jamshid.global_position + Vector2(-20, -24),
		jamshid.global_position + Vector2(-12, -6), 0.9)
	player.cutscene_rest(false, 1)
	await _hooshang("Are the fish biting today?", "happy")
	await _jamshid(jamshid, "They were. Then my cousin swam through their house.", "joyful")
	_splash(rod.global_position + Vector2(-36, -2))
	await _jamshid(jamshid, "Hold that thought!", "excited")
	var fish := await _hook_fish(jamshid, rod)
	await _reel_in(fish, jamshid)
	var fire := await _cut_to_campfire(jamshid, fish, rod)
	await _hooshang("Does my mother know we’re here?", "neutral")
	await _jamshid(jamshid, "Yes. She sent bread and cheese.", "friendly")
	await _hooshang("Where is it?", "neutral")
	await _jamshid(jamshid, "You were late.", "joyful")
	await _hooshang("Jamshid.", "annoyed")
	await _jamshid(jamshid, "Fishing is hungry work. She also said to be home before dark.", "joyful")
	_fade_stars(1.0, 2.0)
	await _tween_sky(NIGHT, 2.0).finished
	await _hold(0.7)
	await _jamshid(jamshid, "You’re quiet today.", "friendly")
	await _hooshang("I had a strange dream.", "vulnerable")
	await _jamshid(jamshid, "Tell me.", "friendly")
	await _hooshang("I was old.", "neutral")
	await _jamshid(jamshid, "Did you have a moustache?", "joyful")
	await _hooshang("Yes.", "happy")
	await _jamshid(jamshid, "Good. Go on.", "friendly")
	await _hooshang("I worked in an office. I didn’t like it, but I stayed for years. Then I lost the job… and I felt lost, too.", "sad")
	await _jamshid(jamshid, "What happened?", "worried")
	await _hooshang("Rumi appeared.", "neutral")
	await _jamshid(jamshid, "Rumi from school?", "joyful")
	await _hooshang("Yes. He taught me how to stay equanimous with my thoughts.", "happy")
	await _jamshid(jamshid, "You’d better start from the beginning.", "friendly")
	await _night_timelapse(player, actor, fish, fire)
	await _hooshang("…and then I woke up here.", "vulnerable")
	await _jamshid(jamshid, "What a dream.", "friendly")
	await _hooshang("Do you remember yours?", "neutral")
	await _jamshid(jamshid, "Almost never. By the time I wake up, they’re gone.", "friendly")
	await _hooshang("This one felt like I’d lived it.", "vulnerable")
	await _jamshid(jamshid, "No wonder you looked so tired.", "worried")
	await _hold(0.7)
	await _hooshang("I’m glad you’re here.", "happy")
	await _jamshid(jamshid, "I’m glad you came down.", "friendly")
	await _hold(0.7)
	await _jamshid(jamshid, "Next time you’re old, come looking for me.", "friendly")
	await _hooshang("Here?", "happy")
	await _jamshid(jamshid, "Here. Or at home. You don’t have to wait for a reason.", "friendly")
	_sound(true)
	actor.play_pose("idle")
	await _jamshid(jamshid, "That can’t be school.", "worried")
	await _hooshang("We talked all night.", "surprised")
	await _jamshid(jamshid, "Your mother is going to kill me.", "worried")
	await _hooshang("I’ll tell her it was my fault.", "happy")
	await _jamshid(jamshid, "She’ll say I should’ve known better.", "worried")
	_sound(true)
	await _jamshid(jamshid, "Come over after school. We can finish talking.", "friendly")
	await _exit_jamshid(jamshid)
	player.cutscene_rest(false, 1)
	player.unfreeze()
	player.input_locked = false


func _night_timelapse(player: Player, actor: Jamshid, fish: Fish, fire: Campfire) -> void:
	var speakers := [player, actor]
	for stage in 3:
		_stars.shoot(stage)
		for line in 3:
			await _emote(speakers[(stage * 3 + line) % 2], EmoteBubble.Kind.ELLIPSIS)
		# Keep both cousins visible as the sky, dinner and fire change together.
		var transition := create_tween().set_parallel()
		transition.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var shifted := [0.0]
		transition.tween_method(func(value: float) -> void:
			_stars.shift_sky(value - shifted[0])
			shifted[0] = value, 0.0, 7.0, 2.0)
		if stage == 0 and is_instance_valid(fish):
			transition.tween_property(fish, "modulate:a", 0.0, 2.0)
		elif stage == 1:
			transition.tween_method(fire.set_strength, 1.0, 0.45, 2.0)
		elif stage == 2:
			transition.tween_method(fire.set_strength, 0.45, 0.0, 3.0)
			if _canvas_mod != null:
				transition.tween_property(_canvas_mod, "color", DAWN, 3.0)
			transition.tween_property(_stars, "amount", 0.0, 3.0)
		await transition.finished
		if stage == 0 and is_instance_valid(fish):
			fish.hide()


# ----------------------------------------------------------------- the cut ----

## The one hard cut. Fade to black, and behind it: put the rod away, restage the
## two of them around a fire (Jamshid left, Hooshang right), set sunset and
## put the same caught fish on the skewer — then fade back up on
## the campfire scene. Returns the fire so the caller can light the room by it.
func _cut_to_campfire(jamshid: JamshidNpc, fish: Fish, rod: Node2D) -> Campfire:
	await _fade_to(1.0, 0.6)
	if is_instance_valid(rod):
		rod.queue_free()

	var actor: Jamshid = jamshid.actor
	var base := jamshid.global_position
	# Jamshid turns from the water to the fire on his right.
	actor.face_left(false)
	actor.play_pose("sit")
	# The fire is between them; Hooshang has come round to sit on the far side.
	var fire := _build_fire_at(base + Vector2(24.0, 0.0))
	fire.light()
	var player := _world.player
	player.global_position = base + Vector2(48.0, -6.0)
	player.velocity = Vector2.ZERO
	player.cutscene_rest(true, -1)

	if _canvas_mod != null:
		_canvas_mod.color = SUNSET
	_fade_stars(0.0, 0.0)
	# The caught fish is now a skewer over the flames.
	if is_instance_valid(fish):
		fish.global_position = fire.global_position + Vector2(0, -22)
		fish.rotation = 0.0
		_cook(fish)
	# Long enough for the fire's own catch-fade to finish under the black.
	await _hold(1.0)
	await _fade_to(0.0, 0.9)
	return fire


## Pull the hooked fish in toward Jamshid's hands.
func _reel_in(fish: Fish, jamshid: JamshidNpc) -> void:
	if not is_instance_valid(fish):
		return
	var to := jamshid.global_position + Vector2(-6.0, -16.0)
	var t := create_tween()
	t.tween_property(fish, "global_position", to, 0.5).set_trans(Tween.TRANS_SINE)
	await t.finished


# --------------------------------------------------------------- the exit ----

## Jamshid runs right, jumps onto a passing carpet and
## rides up and off the top-right of the screen. He is a visual actor, so every
## step is a scripted tween over the carpet sprite,
## not physics.
func _exit_jamshid(jamshid: JamshidNpc) -> void:
	var actor: Jamshid = jamshid.actor
	var here := jamshid.global_position
	var ground_y := here.y
	var jump_x := here.x + 84.0
	var carpet_from := Vector2(here.x + 112.0, ground_y - 48.0)
	var carpet_to := Vector2(here.x + 260.0, ground_y - 190.0)

	# Run along the bank, then jump directly onto the approaching carpet.
	actor.face_left(false)
	actor.play_pose("walk")
	await _tween_node_x(jamshid, jump_x, 0.7)

	var carpet := Sprite2D.new()
	carpet.texture = CARPET_TEXTURE
	carpet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	carpet.scale = Vector2.ONE
	_world.add_child(carpet)
	carpet.global_position = Vector2(jump_x + 112, ground_y - 42)
	create_tween().tween_property(carpet, "global_position", carpet_from + Vector2(0, 1), 0.8)
	actor.play_pose("jump")
	var apex := Vector2(jump_x + 12, ground_y - 76)
	await _tween_arc(jamshid, apex, carpet_from, 0.8)
	actor.play_pose("idle")
	await _hooshang("That’s how you get to school?", "surprised")
	await _jamshid(jamshid, "How do you think I keep arriving before you?", "joyful")
	var ride := create_tween().set_parallel()
	ride.tween_property(jamshid, "global_position", carpet_to, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	ride.tween_property(carpet, "global_position", carpet_to + Vector2(0, 1), 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await ride.finished
	# Off the edge.
	var off := carpet_to + Vector2(140.0, -90.0)
	var gone := create_tween().set_parallel()
	gone.tween_property(jamshid, "global_position", off, 1.0).set_ease(Tween.EASE_IN)
	gone.tween_property(carpet, "global_position", off + Vector2(0, 1), 1.0).set_ease(Tween.EASE_IN)
	await gone.finished
	jamshid.visible = false
	carpet.queue_free()


# --------------------------------------------------------------- fish & rod ----

## A thin fishing rod and line, drawn from Jamshid's hands out over the water.
## Purely cosmetic; freed at the cut. Two Line2Ds under a node parented to him so
## it travels if he shifts.
func _add_fishing_rod(jamshid: JamshidNpc) -> Node2D:
	var root := preload("res://scenes/props/FishingRod.tscn").instantiate() as Node2D
	jamshid.add_child(root)
	_line = root.get_node("Line")
	return root


## The same fish swims here from room setup onward, then bites the line.
func _prepare_pond_fish(room: Node2D, jamshid: JamshidNpc) -> void:
	var water := room.find_children("*", "TileMapLayer", true, false)
	var desired := jamshid.global_position + Vector2(-40, 32)
	var target := desired
	var best := INF
	for layer in water:
		if not layer is WaterLayer:
			continue
		for cell: Vector2i in layer.get_used_cells():
			if layer.get_cell_source_id(cell + Vector2i.LEFT) == -1 or layer.get_cell_source_id(cell + Vector2i.RIGHT) == -1:
				continue
			if layer.get_cell_source_id(cell + Vector2i.DOWN) != -1:
				continue
			var point: Vector2 = layer.to_global(layer.map_to_local(cell))
			var distance := point.distance_to(desired)
			if distance < best:
				best = distance
				target = point - Vector2(0, 5)
	_pond_fish = preload("res://scenes/props/Fish.tscn").instantiate()
	_pond_fish.patrol_width = 16
	room.add_child(_pond_fish)
	_pond_fish.global_position = target.round()
	_pond_fish.reset_patrol_origin()


func _hook_fish(jamshid: JamshidNpc, rod: Node2D) -> Fish:
	var fish := _pond_fish
	fish.hook()
	var tip := rod.global_position + Vector2(-36, -2)
	var approach := create_tween()
	approach.tween_property(fish, "global_position", tip, 1.2).set_trans(Tween.TRANS_SINE)
	await approach.finished
	_caught = true
	_splash(tip)
	var bend: Line2D = rod.get_node("Rod")
	bend.set_point_position(2, Vector2(-18, -17))
	await _hold(0.25)
	bend.set_point_position(2, Vector2(-20, -20))
	return fish


func _process(_delta: float) -> void:
	if is_instance_valid(_line) and is_instance_valid(_rod):
		var rod_shape: Line2D = _rod.get_node("Rod")
		_line.set_point_position(0, rod_shape.get_point_position(2))
	if _caught and is_instance_valid(_line) and is_instance_valid(_pond_fish):
		_line.set_point_position(1, _line.to_local(_pond_fish.global_position + Vector2(4, 0)).round())


func _cook(fish: Fish) -> void:
	fish.cook()


func _splash(at: Vector2) -> void:
	var splash := Node2D.new()
	splash.set_script(preload("res://scenes/props/fishing_splash.gd"))
	_world.add_child(splash)
	splash.global_position = at.round()
	_sound(false)


## Small deterministic PCM cues: a metallic school bell and a short water splash.
func _sound(bell: bool) -> void:
	var audio := AudioStreamPlayer.new()
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration := 1.8 if bell else 0.3
	var data := PackedByteArray()
	data.resize(int(22050 * duration) * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in data.size() / 2:
		var t := float(i) / 22050.0
		var sample := (sin(TAU * 880 * t) + 0.45 * sin(TAU * 2341 * t)) * exp(-3.5 * t) if bell else rng.randf_range(-1, 1) * exp(-16 * t)
		data.encode_s16(i * 2, int(sample * 7000 * minf(t * 100, 1.0)))
	stream.data = data
	audio.stream = stream
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()


func _build_fire_at(pos: Vector2) -> Campfire:
	var fire: Campfire = CAMPFIRE_SCENE.instantiate()
	_world.add_child(fire)
	fire.global_position = pos
	return fire


# -------------------------------------------------------------- environment ----

## The stars go on their OWN CanvasLayer, not in the world's Backdrop. Two
## reasons, both learned the hard way: the StarField draws in a fixed 320x180
## SCREEN box, so in world space it lands at the world origin and never where
## the camera is actually looking; and a separate CanvasLayer is immune to the
## default-canvas CanvasModulate, so the night tint cannot dim it. Layer 2 puts
## it in front of the (tinted) sky; the stars only fill the upper sky band
## (StarField.horizon_y), well above the characters on the bank, so nothing
## draws over a face.
func _build_stars() -> void:
	# Added to THIS node, not to _world: _build_stars runs from _ready while the
	# world is still setting up its own children, and add_child on a parent that
	# is mid-setup fails ("Parent node is busy setting up children"). A
	# CanvasLayer is screen-space per viewport wherever it sits in the tree, so
	# hanging it off the beats node (which is not busy) is both correct and safe
	# — the same reason _build_fade adds its layer to self.
	var layer := CanvasLayer.new()
	layer.name = "StarLayer"
	layer.layer = 2
	add_child(layer)
	_stars = STAR_FIELD_SCENE.instantiate()
	_stars.horizon_y = 62.0
	_stars.amount = 0.0
	layer.add_child(_stars)


## Returns the Tween rather than awaiting it, so a caller can either block on it
## (`await _tween_sky(...).finished`) or hold it and let it run under other beats
## (the night-to-dawn tween runs while the two trade silent "..." reactions).
func _tween_sky(to: Color, time: float) -> Tween:
	var t := create_tween()
	if _canvas_mod != null:
		t.tween_property(_canvas_mod, "color", to, time).set_trans(Tween.TRANS_SINE)
	else:
		t.tween_interval(time)
	return t


## Fade the stars toward `to` over `time`. Not awaited by callers that want the
## night to keep changing while dialogue plays.
func _fade_stars(to: float, time: float) -> void:
	if _stars == null:
		return
	if time <= 0.0:
		_stars.amount = to
		return
	create_tween().tween_property(_stars, "amount", to, time)


# --------------------------------------------------------------- dialogue -----

func _hooshang(text: String, face: String) -> void:
	await Dialogue.say("Hooshang", text, HOOSHANG_PALE, CHILD_FACES.get(face, CHILD_FACES["neutral"]),
		(DialogueBox.Side.RIGHT if _speaker != null and _speaker.global_position.x < _world.player.global_position.x else DialogueBox.Side.LEFT),
		DialogueBox.VSide.BOTTOM)


func _jamshid(jamshid: JamshidNpc, text: String, face: String) -> void:
	var side: int = jamshid.portrait_side(_world.player)
	await Dialogue.say("Jamshid", text, JAMSHID_WARM, Jamshid.portrait(face), side, DialogueBox.VSide.BOTTOM)


func _emote(over: Node2D, kind: EmoteBubble.Kind) -> void:
	if over == null or not is_instance_valid(over):
		return
	var bubble: EmoteBubble = EMOTE_SCENE.instantiate()
	over.add_child(bubble)
	bubble.position = Vector2(0.0, emote_height)
	await bubble.play(kind)
	if is_instance_valid(bubble):
		bubble.queue_free()


# --------------------------------------------------------------- plumbing -----

## Black sheet on a high CanvasLayer, for the one cut. Same as Act1Beats.
func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func _fade_to(alpha: float, time: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", alpha, time)
	await t.finished


func _tween_node_x(node: Node2D, to_x: float, time: float) -> void:
	var t := create_tween()
	t.tween_property(node, "global_position:x", to_x, time)
	await t.finished


## An L-of-a-jump arc: up to `apex`, then down to `to`, via two eased tweens so
## it reads as a launch and a landing rather than a straight slide.
func _tween_arc(node: Node2D, apex: Vector2, to: Vector2, time: float) -> void:
	var t := create_tween()
	t.tween_property(node, "global_position", apex, time * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "global_position", to, time * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished


func _hold(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _find_world() -> LdtkWorld:
	var n := get_parent()
	while n != null:
		if n is LdtkWorld:
			return n
		n = n.get_parent()
	return null


func _find_room(rname: String) -> Node2D:
	for room in _world.rooms:
		if str(room.name) == rname:
			return room
	return null


func _find_jamshid(node: Node) -> JamshidNpc:
	if node is JamshidNpc:
		return node
	for child in node.get_children():
		var found := _find_jamshid(child)
		if found != null:
			return found
	return null
