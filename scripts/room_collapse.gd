class_name RoomCollapse
## Everything in a room that is hanging in the air comes down at once.
##
## The beat this exists for: Hooshang walks into the room and the level itself
## gives up — the belts, the spikes and the ledges he was going to use drop out
## of the sky and land in a heap. It is staging, not a mechanic: the props keep
## working exactly as they did, they are simply somewhere lower afterwards.
##
## WHAT FALLS. Anything of a kind that could plausibly be resting on something
## (see FALLS_UNDER) with nothing solid under it. Markers, triggers and doorways
## are left alone on purpose — an Exit sign sliding to the floor is a bug, not a
## collapse, and a trigger that moves stops covering the line it was drawn
## across. A prop already sitting on the ground does not move either, so the room
## reads as the AIRBORNE half of it failing rather than as everything twitching.
##
## HOW IT FALLS. Real free fall, not a slide: each prop is tweened down to the
## first solid surface beneath it with a quadratic ease-in, which is what gravity
## actually looks like, over a duration derived from the distance. They are
## staggered left to right so the room comes apart as a ripple instead of a
## single snap.
##
## Static, and taking its host as an argument, because a collapse is a thing that
## happens to a room once — there is no state worth keeping alive afterwards, and
## nothing else should be able to ask a half-fallen room questions.

## Prop types that take part. Order does not matter; `is` covers subclasses, so
## Hazard brings the four GlassSpikes surfaces with it.
##
## Kept as a list of TYPES rather than a group, because joining a group is a
## decision each prefab would have to remember to make and the failure is silent:
## a new hazard that forgot would simply hang in the air through the whole beat
## with nothing to point at. Adding a kind here is one line and is visible.
##
## NOT NoteTile, deliberately. A sounding pad is the one prop in these rooms that
## lights itself and is meant to be looked at, and it stays where it was put:
## rooms 16, 17 and 18 each keep a pad layout you can recognise from its twin on
## the way out, and a collapse that rearranges them throws that away for a
## clatter. They also make the surrounding physics honest — a pad is a solid body
## that is NOT coming down, so props above one can measure their landing on it
## like any other floor. Room 18 used to end its collapse with four props still
## hanging in the air for exactly the opposite reason.
const FALLS_UNDER := "Hazard, ConveyorBelt, SlideZone, Lemon"

## Free-fall acceleration used to time the drops, px/s². Deliberately heavier
## than the player's own gravity — he falls with air under him and a jump to
## control, this is masonry letting go.
const GRAVITY := 900.0
## Slowest a fall is allowed to be, in seconds. A prop hanging one pixel up would
## otherwise land in a frame or two and read as a flicker.
const MIN_FALL := 0.18
## How much later each prop starts than the one to its left, in seconds. Small:
## this is a ripple across the room, not a queue.
const STAGGER := 0.05
## Farther than any room is tall, so the ray finds the floor from any height.
const REACH := 512.0
## Anything already within this many px of the ground counts as resting on it and
## is left where it is.
##
## One tile, not a hair's breadth. A ConveyorBelt's collision box stops a few
## pixels short of the bottom of its cell, so EVERY belt in the game reads as
## hovering 3-9px up — measured in Level_14, where a 2px threshold called eight
## floor-level belts airborne and dropped them by single digits. That is the
## "whole room twitches" failure this constant exists to prevent, and the honest
## line is the grid the rooms are built on: less than a cell of air under it and
## nothing is visibly hanging.
const SETTLED := 16.0
## How far a landing prop squashes, and for how long. The squash is what sells
## the impact — without it a prop that stops dead reads as the tween ending.
const LAND_SQUASH := Vector2(1.18, 0.8)
const LAND_TIME := 0.09


## Drop everything airborne in `room`. Returns the props it moved, so a caller
## can hang sound or dust off the same list.
##
## `host` owns the tweens: they have to live on a node that outlives the fall,
## and the props themselves are the wrong choice — a Lemon freeing itself
## mid-collapse (the player can be standing in it) would take its own tween with
## it and leave the beat half played.
static func drop(room: Node2D, host: Node) -> Array[Node2D]:
	var falling: Array[Node2D] = []
	if room == null or host == null or not host.is_inside_tree():
		return falling

	# Sorted by x so the stagger is a ripple across the room and, being derived
	# from position rather than from tree order, always the same ripple — the
	# LDtk import builds entities in whatever order they were placed.
	var airborne := _airborne_in(room)
	airborne.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.x < b.global_position.x)

	for i in airborne.size():
		var prop: Node2D = airborne[i]
		var drop_to: float = prop.get_meta("collapse_landing")
		var distance: float = drop_to - prop.global_position.y
		var fall_time := maxf(sqrt(2.0 * distance / GRAVITY), MIN_FALL)
		var tween := host.create_tween()
		tween.tween_interval(i * STAGGER)
		# Quadratic ease-in IS free fall — distance goes with the square of time.
		tween.tween_property(prop, "global_position:y", drop_to, fall_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# The opt-in twin of collapse_anchored(): a prop that wants to change what
		# it looks like on impact (GlassSpikes flipping a ceiling strip to a floor
		# one) gets the chance right as it lands, before the squash sells the hit.
		if prop.has_method("collapse_landed"):
			tween.tween_callback(prop.collapse_landed)
		tween.tween_property(prop, "scale", prop.scale * LAND_SQUASH, LAND_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(prop, "scale", prop.scale, LAND_TIME * 2.0) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		falling.append(prop)
	return falling


## How long the whole collapse takes, so a caller can hold the player for exactly
## as long as it lasts rather than guessing a number that drifts out of step with
## the constants above.
static func duration(room: Node2D) -> float:
	var airborne := _airborne_in(room)
	# Zero, not the trailing squash: "nothing is hanging" has to be tellable from
	# "one thing is hanging an inch up", because a caller freezes the player for
	# whatever this returns.
	if airborne.is_empty():
		return 0.0
	var longest := 0.0
	for i in airborne.size():
		var prop: Node2D = airborne[i]
		var distance: float = prop.get_meta("collapse_landing") - prop.global_position.y
		longest = maxf(longest,
			i * STAGGER + maxf(sqrt(2.0 * distance / GRAVITY), MIN_FALL))
	return longest + LAND_TIME * 3.0


## Every prop in `room` with nothing under it, each tagged with the y its origin
## ends up at. Measured once and cached on the node so drop() and duration()
## cannot disagree about where a thing lands.
static func _airborne_in(room: Node2D) -> Array[Node2D]:
	var props := _props_in(room)
	# EVERY prop is excluded from EVERY ray, not just its own bodies. A
	# ConveyorBelt carries a walkable floor on layer 1, and a NoteTile is a solid
	# body outright, so a prop hanging above one measures its landing as "resting
	# on that" — and then the thing under it falls too, leaving it stranded in
	# mid-air with the collapse already finished. Level_15 and Level_19 each ended
	# a collapse with four props still hanging, for exactly this.
	#
	# Nothing that is itself coming down counts as ground. Only the room does.
	var skip: Array[RID] = []
	for prop in props:
		skip.append_array(_bodies_of(prop))

	var found: Array[Node2D] = []
	for prop in props:
		var landing := _landing_for(prop, skip)
		if landing - prop.global_position.y <= SETTLED:
			continue
		prop.set_meta("collapse_landing", landing)
		found.append(prop)
	return found


static func _props_in(node: Node) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for child in node.get_children():
		if child is Node2D and _falls(child):
			found.append(child)
		else:
			found.append_array(_props_in(child))
	return found


## Whether this node is one of the kinds that take part, AND has not opted out.
##
## THE OPT-OUT is `collapse_anchored()`, and a prop that answers true is not part
## of the collapse at all: it does not fall, and — because it is not in the
## falling set — it goes on counting as solid ground for whatever is above it.
## That second half matters as much as the first (see _airborne_in).
##
## Duck-typed rather than a second type list, so a prop can decide PER INSTANCE.
## GlassSpikes is the case that needs it: the same class is a floor strip, a
## ceiling strip and two wall strips, and only the floor one is ever "hanging".
##
## String comparison against FALLS_UNDER rather than a chain of `is` checks so
## the list stays one readable line — the classes are all globals, so the name
## is exact.
static func _falls(node: Node) -> bool:
	if node.has_method("collapse_anchored") and node.collapse_anchored():
		return false
	for kind in FALLS_UNDER.split(", "):
		if node.is_class(kind) or _script_is(node, kind):
			return true
	return false


## `is_class` only knows ENGINE classes; a GDScript `class_name` is invisible to
## it. Walk the script inheritance chain by hand so a GlassSpikes still answers
## to "Hazard".
static func _script_is(node: Node, kind: String) -> bool:
	var script: Script = node.get_script()
	while script != null:
		if script.get_global_name() == kind:
			return true
		script = script.get_base_script()
	return false


## The y this prop's ORIGIN settles at: cast down from the bottom of whatever it
## collides with, find the first solid surface, then put that bottom edge on it.
##
## `exclude` is every body that must not count as ground — see _airborne_in. It
## always contains the prop's own: a ConveyorBelt carries its own walkable floor
## on layer 1, so without that much every belt in the room would report it is
## already standing on something (itself) and nothing would ever fall.
static func _landing_for(prop: Node2D, exclude: Array[RID] = []) -> float:
	var space := prop.get_world_2d().direct_space_state
	var bottom := _bottom_of(prop)
	var query := PhysicsRayQueryParameters2D.create(
		Vector2(prop.global_position.x, bottom + 1.0),
		Vector2(prop.global_position.x, bottom + REACH),
		1)  # layer 1 = world
	query.exclude = _bodies_of(prop) + exclude
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return prop.global_position.y  # nothing under it at all — leave it be
	# Keep the prop's own origin-to-bottom offset, so a spike strip lands with its
	# points on the floor rather than its centre in it.
	return hit.position.y - (bottom - prop.global_position.y)


## World-space y of the prop's lowest collision edge.
static func _bottom_of(prop: Node2D) -> float:
	var lowest := prop.global_position.y
	for shape in _shapes_in(prop):
		var rect := shape.shape as RectangleShape2D
		if rect == null:
			continue
		lowest = maxf(lowest, shape.global_position.y + rect.size.y * 0.5)
	return lowest


static func _shapes_in(node: Node) -> Array[CollisionShape2D]:
	var found: Array[CollisionShape2D] = []
	for child in node.get_children():
		if child is CollisionShape2D:
			found.append(child)
		found.append_array(_shapes_in(child))
	return found


## RIDs of every physics body the prop owns, for the ray's exclude list.
static func _bodies_of(prop: Node) -> Array[RID]:
	var rids: Array[RID] = []
	if prop is CollisionObject2D:
		rids.append((prop as CollisionObject2D).get_rid())
	for child in prop.get_children():
		rids.append_array(_bodies_of(child))
	return rids
