class_name OfficeWindowPanes
extends RefCounted
## Native-pixel transparent glass; wall, sash, blinds and dividers stay opaque.
## New baked backgrounds fail closed until their glass is authored here.
static func for_room(room: String) -> Array:
	if room == "Level_25":
		room = "Level_0"  # Homecoming uses the opening cubicle artwork.
	var openings := {
		"Level_0": [Rect2(146,47,27,71), Rect2(177,47,81,71), Rect2(263,47,27,71)],
		"Level_1": [Rect2(84,25,14,81)],
		"Level_2": [Rect2(26,56,24,75), Rect2(54,56,23,75), Rect2(81,56,22,75)],
		"Level_3": [Rect2(202,38,28,26), Rect2(233,38,27,26), Rect2(264,38,25,26), Rect2(202,68,28,32), Rect2(233,68,27,32), Rect2(264,68,25,32), Rect2(202,104,28,25), Rect2(233,104,27,25), Rect2(264,104,25,25)],
		"Level_4": [Rect2(81,25,35,76), Rect2(121,25,36,76), Rect2(162,25,35,76), Rect2(202,25,31,76)],
		"Level_5": [Rect2(160,32,66,72), Rect2(231,32,67,72)],
		"Level_6": [Rect2(74,25,23,32), Rect2(101,25,22,32), Rect2(74,62,23,32), Rect2(101,62,22,32)]
	}
	return openings.get(room, [])
