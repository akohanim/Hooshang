@tool
extends Node2D
## Opening-room dressing in room-local pixels. No collision or gameplay state.

func _draw() -> void:
	# Felt partition: quiet woven texture, inset trim and a grounded skirting.
	draw_rect(Rect2(50, 50, 92, 44), Color("303a3f"))
	for y in range(52, 93, 3):
		draw_line(Vector2(51, y), Vector2(140, y), Color("323d43"))
	draw_rect(Rect2(50, 49, 92, 1), Color("737b75"))
	draw_rect(Rect2(50, 92, 92, 3), Color("202930"))
	# A life spent at this desk: noticeboard, pinned papers, a small calendar.
	draw_rect(Rect2(82, 58, 27, 17), Color("212a30"))
	draw_rect(Rect2(83, 59, 25, 15), Color("625545"))
	for sheet in [Rect2(85, 61, 7, 10), Rect2(96, 62, 9, 8)]:
		draw_rect(sheet, Color("a5a391"))
		draw_rect(Rect2(sheet.position + Vector2(2, 3), Vector2(sheet.size.x - 3, 1)), Color("6b777a"))
		draw_rect(Rect2(sheet.position + Vector2(2, 6), Vector2(3, 1)), Color("6b777a"))
		draw_rect(Rect2(sheet.position + Vector2(3, 0), Vector2.ONE), Color("a87654"))
	draw_rect(Rect2(122, 62, 10, 12), Color("959b94"))
	draw_rect(Rect2(122, 62, 10, 3), Color("745957"))
	for y in [67, 70]:
		for x in [124, 127, 130]:
			draw_rect(Rect2(x, y, 1, 1), Color("4b5961"))
	# Desk legs actually meet the floor; stacked paperwork and a coffee cup.
	draw_rect(Rect2(89, 85, 24, 3), Color("786451"))
	draw_rect(Rect2(89, 85, 24, 1), Color("b29c77"))
	for x in [90, 111]:
		draw_rect(Rect2(x, 88, 2, 8), Color("39454c"))
	draw_rect(Rect2(106, 82, 7, 3), Color("a5ac9e"))
	draw_line(Vector2(106, 83), Vector2(112, 83), Color("646e70"))
	draw_rect(Rect2(88, 81, 3, 4), Color("a9b6ae"))
	draw_rect(Rect2(87, 82, 1, 2), Color("7a9696"))
	# Monitor bezel, stand and a narrow keyboard ground the glowing screen.
	draw_rect(Rect2(96, 75, 10, 1), Color("24343e"))
	draw_rect(Rect2(96, 76, 1, 7), Color("24343e"))
	draw_rect(Rect2(105, 76, 1, 7), Color("24343e"))
	draw_rect(Rect2(96, 82, 10, 1), Color("24343e"))
	draw_rect(Rect2(100, 83, 2, 2), Color("50616a"))
	draw_rect(Rect2(94, 84, 10, 1), Color("909c99"))
	# Ceiling conduit above the workstation.
	draw_line(Vector2(51, 23), Vector2(139, 23), Color("303e48"))
	draw_line(Vector2(139, 23), Vector2(139, 45), Color("303e48"))
	# Sill and low cool reflections visually anchor the tall night window.
	draw_rect(Rect2(146, 94, 105, 2), Color("384856"))
	draw_line(Vector2(148, 94), Vector2(224, 94), Color("536674"))
