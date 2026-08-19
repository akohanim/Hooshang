class_name DashTutorial
extends Node
## Level_24: the room that teaches the diagonal dash.
##
## STANDALONE ON PURPOSE. Nothing exits into Level_24 and it is not in
## Game.LEVELS, so it is only reachable from the debug picker / level select —
## it is a room to test the lesson in, not yet a room in the Act. Wiring it into
## the run is a one-line change to whichever room should lead to it, once the
## renumber lands.
##
## THE SHAPE OF THE LESSON. He crosses a long run of ceiling panels that are
## already failing, and it dead-ends: the only way on is a brick ledge
## `LEDGE_RISE` px above the panels, which is just past the 34px a full jump
## reaches. So a jump alone cannot do it and there is nothing to be clever with —
## the diagonal dash is the only answer, which is what makes it teachable.
##
## THE PANELS HOLD LONG ENOUGH TO GET THERE. Each CrumblingPlatform starts its
## own half-second timer when he first stands on it, which is right for a hazard
## and wrong for a lesson: the point is to read a prompt and try a new move, not
## to be dropped while doing it. `hold_time` relaxes every panel in THIS room
## only, so the prop keeps its own tuning everywhere else.
##
## Rumi comes down for it, because a new move is a gift in this game and every
## other one has been handed over rather than announced.

## The room this belongs to. Everything here is inert in every other room.
const ROOM := "Level_24"

@export_group("Where")
## Where the floor is taken away and he is caught. NOT an independent number:
## it is set to the hang point's x at room entry, because catching him anywhere
## other than where he is standing means teleporting him there, and the 24px
## that used to be between them is a visible jump.
var arm_at_x := 0.0
## The ledge he is being asked to reach, for the check that he made it.
@export var ledge_x := 744.0
@export var ledge_top_y := 1496.0

## Where he is caught, relative to the ledge's bottom-left corner. Left of it
## and a little below, so an up-forward dash carries him over the lip and a flat
## one plainly cannot: the dash covers 39px, which from here clears the 36px
## rise only if some of it is spent going up.
@export var hang_offset := Vector2(-30.0, 16.0)

@export_group("The beat")
## What every crumbling panel in this room gets instead of its own timing, while
## he is crossing.
@export var hold_time := 2.4
## ...and what they get once the floor is pulled. Short: this is the drop, not a
## warning.
@export var collapse_time := 0.35
## Seconds between one panel going and the next, left to right.
@export var collapse_stagger := 0.035
## Rumi's lines. One, because a tutorial that talks longer than the move takes
## is a tutorial nobody reads twice.
@export var lines: Array[String] = [
	"Hold the way you want to go — up and onward — and dash.",
]

var _world: LdtkWorld
var _player: Player
var _armed := false
var _done := false
var _prompt: InputPrompt
var _rumi: LdtkRumiTrigger
## Where he is pinned while the lesson is up, and whether the pin is live.
var _hang := Vector2.ZERO
var _held := false
var _pulled := false


func _ready() -> void:
	_world = get_parent() as LdtkWorld
	if _world == null:
		push_warning("DashTutorial expects to be a child of LdtkWorld.")
		set_process(false)
		return
	_world.room_changed.connect(_on_room_changed)
	# After the player, so the pin below is the last word on his position each
	# frame rather than something _apply_run overwrites a moment later.
	process_priority = 100


func _on_room_changed(room: Node2D) -> void:
	if str(room.name) != ROOM:
		_teardown()
		return
	_player = _world.player
	# It is the dash tutorial; he has a dash in it whatever a save slot says.
	_player.has_dash = true
	_hang = Vector2(ledge_x, ledge_top_y) + hang_offset
	arm_at_x = _hang.x
	_relax_panels()
	# Re-armed on every entry, so a retry teaches the same lesson rather than
	# dropping him into a room whose prompt has already been spent.
	_armed = true
	_done = false
	_pulled = false


## Collapse what is left of the run, left to right.
##
## Staggered rather than all at once: a whole floor vanishing on one frame reads
## as the level being switched off, where a run of panels going in sequence reads
## as the thing he is standing on failing — and it puts the last one under his
## feet, which is the one that drops him.
func _pull_the_floor() -> void:
	_pulled = true
	var rect := _world.room_rect(_world.current_room)
	var panels: Array = []
	for node in get_tree().get_nodes_in_group("crumbling"):
		var p := node as CrumblingPlatform
		if p != null and rect.has_point(p.global_position):
			panels.append(p)
	panels.sort_custom(func(a: CrumblingPlatform, b: CrumblingPlatform) -> bool:
		return a.global_position.x < b.global_position.x)
	for i in panels.size():
		var p: CrumblingPlatform = panels[i]
		p.crumble_time = collapse_time
		p.give_way(collapse_time - float(i) * collapse_stagger)


## Give this room's panels a gentler timer. Found by group and filtered by
## position rather than by a per-room list: the group is how the reset sweep
## already finds them, and a room is a rectangle.
func _relax_panels() -> void:
	var rect := _world.room_rect(_world.current_room)
	for node in get_tree().get_nodes_in_group("crumbling"):
		var p := node as CrumblingPlatform
		if p != null and rect.has_point(p.global_position):
			p.crumble_time = hold_time


## The pin, and the two things that end it.
##
## In _physics_process, not _process: it writes velocity and position, and doing
## that on render frames fights move_and_slide for who moved him last.
##
## `_armed` gates the CATCH only, and is cleared the moment the beat starts so it
## cannot re-enter while Rumi is talking. It deliberately does NOT gate the rest:
## guarding the whole function with it meant the prompt went up and the dash that
## answers it was never watched for.
func _physics_process(_delta: float) -> void:
	if _done or _player == null:
		return
	if _prompt == null and not _held:
		if not _armed or _player.global_position.x < arm_at_x:
			return
		# THE FLOOR IS TAKEN, not waited for. Relaxed to hold long enough to
		# cross, the panels also hold long enough to walk the whole run and never
		# need the move — so reaching this point collapses what is left of them
		# and he goes with it.
		if not _pulled:
			_pull_the_floor()
			return
		if not _player.is_on_floor() and _player.velocity.y > 0.0:
			_catch()
		return
	# The move itself: a dash with BOTH axes in it, aimed upward. A flat dash is
	# the move he already has, so only the diagonal counts as having learned it.
	if _player.state == Player.State.DASH:
		if _player.dash_dir.y < -0.3 and absf(_player.dash_dir.x) > 0.3:
			_finish()
		return          # let a wrong dash play out; the pin takes him back after
	if _held:
		_pin()


## Hold him exactly where he was caught, with the dash still in his hands.
##
## Not Player.hold(): that takes his controls away and stops his physics, which
## is right for a cutscene and wrong here — the whole point is that he can still
## press something. Velocity is zeroed rather than gravity disabled so nothing in
## player.gd has to know this beat exists.
func _pin() -> void:
	_player.velocity = Vector2.ZERO
	_player.global_position = _hang
	_player.dash_available = true


## Rumi speaks FIRST, then the prompt goes up.
##
## Not for pacing — the dialogue box consumes the jump key to advance a line
## (it calls set_input_as_handled), so a prompt shown underneath one is telling
## him to press a button the box is holding. He reads, then he tries.
## Catch him mid-fall and start the lesson.
func _catch() -> void:
	_held = true
	_player.state = Player.State.FALL
	_pin()
	_begin()


func _begin() -> void:
	_armed = false          # so the catch stops re-entering while this runs
	await _call_rumi()
	if _done or not is_instance_valid(_player):
		return
	_prompt = load("res://scenes/ui/InputPrompt.tscn").instantiate()
	_world.add_child(_prompt)
	_prompt.show_at(_player.global_position + Vector2(0.0, -6.0))


## Rumi drops in beside him, says his piece, and stays until the move is made.
func _call_rumi() -> void:
	_rumi = LdtkRumiTrigger.make()
	_rumi.defer_to_cutscene = true
	_rumi.global_position = _player.global_position + Vector2(-26.0, 0.0)
	_world.add_child(_rumi)
	_rumi.appear(_player.global_position.x - 26.0)
	for line in lines:
		await Dialogue.say("Rumi", line, LdtkRumiTrigger.RUMI_GOLD, null,
			_rumi.portrait_side(_player), DialogueBox.VSide.TOP)


func _finish() -> void:
	_done = true
	_held = false
	if _prompt != null:
		_prompt.dismiss()
		_prompt = null
	if _rumi != null:
		_rumi.vanish()
		_rumi = null


func _teardown() -> void:
	_armed = false
	_held = false
	_pulled = false
	if _prompt != null:
		_prompt.dismiss()
		_prompt = null
	if _rumi != null:
		_rumi.vanish()
		_rumi = null
