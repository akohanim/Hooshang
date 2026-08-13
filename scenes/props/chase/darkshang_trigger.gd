@tool
class_name DarkshangTrigger
extends Area2D
## The threshold that starts the chase. Cross it and the shadow appears at his
## spawn point, two lines are spoken, and only then does he begin to move.
##
## Separate from `DarkshangSpawn` on purpose: WHERE he comes from and WHEN he
## comes are different level-design questions. The spawn is a spot behind you
## that wants to be off screen or inside a wall; the trigger is a line across
## the corridor that wants to be exactly where the reveal reads best. Tying them
## together would mean walking into his spawn point to start the chase, which is
## the one place you never want to be.
##
## A room holding one of these puts its shadow on standby at load — see
## Darkshang.stand_by(). Placing a trigger IS the statement "he waits for me",
## so there is no second flag to forget.
##
## FIRES ONCE, and unlike a SurgePoint it is never re-armed. Crossing back over
## the line that started a boss fight should not start it again.
##
## Place one in LDtk as a `DarkshangTrigger` and stretch it across the corridor.

## Fired the instant the player crosses, before the dialogue. A room script can
## hang a camera shake, a light cut or a music change off the same beat.
signal triggered(player: Player)
## Fired when the beat has finished and the chase is actually running.
signal chase_begun()

## Full size of the trigger box in px. LDtk sets this from the box you drag.
## Normally spans the full height of the corridor: it is a line the player
## crosses, and one he can jump over is one he will.
@export var size := Vector2(16.0, 96.0):
	set(value):
		size = value
		_update_extents()

## Which beat plays on the crossing. "" plays nothing and starts the chase
## immediately, which is what a second chase in a later Act probably wants —
## the reveal only lands once.
@export var dialogue_id := "darkshang_appears"

## Beat before he is spoken about, in seconds. He is standing there and nobody
## has said anything: the pause IS the reaction, and it does more than a line
## would. Long enough to register, short enough not to feel like a hang.
@export var reveal_pause := 0.9

## Editor-only overlay colour, a staging aid. Purple, matching DarkshangSpawn —
## the two entities are halves of one event.
const EDITOR_TINT := Color(0.61, 0.30, 1.0, 0.22)

## A face per state, per speaker — the same convention Act1Beats.FACES uses, and
## kept separate per speaker for the same reason: a beat names the STATE it wants
## and never a file, so re-cutting the portrait sheet never touches this script
## (CLAUDE.md, dialogue rules). Two maps rather than one so the two of them can
## both own a "sorrowful" later without colliding.
const FACES := {
	"shocked": preload("res://assets/portraits/hooshang_shocked.png"),
	"vulnerable": preload("res://assets/portraits/hooshang_vulnerable.png"),
}
const RUMI_FACES := {
	"wistful": preload("res://assets/portraits/rumi_wistful.png"),
	"sorrowful": preload("res://assets/portraits/rumi_sorrowful.png"),
	"urgent": preload("res://assets/portraits/rumi_urgent.png"),
}
const HOOSHANG_PALE := Color(1.0, 1.0, 1.0, 1.0)
const RUMI_GOLD := Color(1.0, 0.82, 0.42, 1.0)

## The beats this trigger knows how to play, by `dialogue_id`.
## Each line is [speaker, text, portrait state].
##
## Written out in full here rather than as an id handed to a story script,
## because the chase is self-contained: a room with these four nodes in it plays
## the whole sequence with no cutscene wiring at all. If Act I later grows a
## script that owns every beat, this is one dictionary to move.
##
## THE SHAPE OF THE SCENE. He asks what it is; Rumi does not answer with a name,
## he answers with what it IS — a seed Hooshang sowed and kept watering himself.
## Hooshang works out the trap in his own words, which is what makes the last
## three lines land: it cannot be fought for him, because he is the one growing
## it. Only then the warning, and only then does the shadow move.
const BEATS := {
	"darkshang_appears": [
		["Hooshang", "What is that??", "shocked"],
		["Rumi", "That is the seed you have sown and watered, jaan. Water a bad thought faithfully enough, and it grows tall enough to shut out the light.", "wistful"],
		["Hooshang", "Meaning... every time the thought came, I fed it. And it grew.", "vulnerable"],
		["Rumi", "Yes. It wears the face of total darkness.", "sorrowful"],
		["Rumi", "No one can fight this for you. Not even me.", "sorrowful"],
		["Rumi", "Don't let it absorb you.", "urgent"],
	],
}

## Whether the chase has already been started here.
var spent := false

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 8  # layer 4 "triggers"
	collision_mask = 2   # the player and nothing else
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_update_extents()
	add_to_group("darkshang_trigger", true)
	if Engine.is_editor_hint():
		return
	# Put the room's shadow on standby before the player can possibly reach him.
	# Deferred by one frame: the LDtk import builds entities in whatever order
	# they were placed, so the Darkshang may not be in the tree yet.
	_stand_by_shadow.call_deferred()
	body_entered.connect(_on_body_entered)


## Hide the room's shadow until this trigger says otherwise.
func _stand_by_shadow() -> void:
	var shadow := _shadow()
	if shadow != null:
		shadow.stand_by()


## The Darkshang belonging to THIS room. Scoped to the trigger's own room rather
## than taken from the group at large: the whole Act is loaded at once, so an
## unscoped lookup would reach a shadow in a room the player has never seen
## (STYLE_GUIDE §9, same reason the story doors scope to their parent).
func _shadow() -> Darkshang:
	var mine := get_parent()
	for node in get_tree().get_nodes_in_group("darkshang"):
		if node is Darkshang and node.get_parent() == mine:
			return node
	return null


func _on_body_entered(body: Node2D) -> void:
	if spent or body is not Player:
		return
	spent = true
	_play(body as Player)


## The reveal: he appears, the beat plays with the player held still, then he
## starts moving.
##
## The order matters and is the whole point of the trigger. Starting the chase
## first would have him closing the gap through the whole exchange while the
## player cannot move — a boss fight that begins by killing you for reading. He
## is visible for all of it; only his movement waits, however long the beat runs.
##
## The banner sits at its default TOP. Both of them are on the floor here — the
## shadow spawns at the bottom-right of the room and Hooshang is looking at him —
## so the top of the screen is the clear half (CLAUDE.md, dialogue rules).
func _play(player: Player) -> void:
	triggered.emit(player)
	var shadow := _shadow()
	if shadow != null:
		# "**darkshang appears**" is a stage direction, so it is PLAYED, never
		# printed (CLAUDE.md, dialogue rules): he is put at his spawn point and
		# shown. reveal() leaves him DORMANT — visible but not yet hunting.
		shadow.reveal()
	var locked := player.input_locked
	player.input_locked = true
	await get_tree().create_timer(reveal_pause).timeout
	for line in BEATS.get(dialogue_id, []):
		if line[0] == "Rumi":
			# His face goes on the side he is standing on, and he is not staged
			# here — he is a voice over Hooshang's shoulder. RIGHT because the
			# shadow comes from the right and Hooshang is looking at it, so the
			# two speakers still read as being on opposite sides.
			await Dialogue.say("Rumi", line[1], RUMI_GOLD, RUMI_FACES.get(line[2]),
				DialogueBox.Side.RIGHT)
		else:
			await Dialogue.say("Hooshang", line[1], HOOSHANG_PALE, FACES.get(line[2]))
	player.input_locked = locked
	if shadow != null:
		shadow.start_chase()
	chase_begun.emit()


func _update_extents() -> void:
	if _shape == null:
		return
	(_shape.shape as RectangleShape2D).size = size.max(Vector2.ONE)
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(-size * 0.5, size), EDITOR_TINT)
	# A bar down the middle: this is a LINE the player crosses, and the box is
	# only how wide the line is.
	draw_rect(Rect2(Vector2(-1.0, -size.y * 0.5), Vector2(2.0, size.y)),
		Color(EDITOR_TINT, 0.8))
