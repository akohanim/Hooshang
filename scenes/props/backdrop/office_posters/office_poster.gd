@tool
extends Node2D
## A paper decal only: inherits room lighting and stays behind gameplay geometry.
const SLOGANS := ["Deadlines: NOW", "Climb to success", "Every second counts",
	"Smile. You're at work.", "Teamwork means overtime", "Your best is the minimum",
	"Rise. Work. Repeat.", "Productivity is happiness", "Think of the shareholders"]
## Native 3x5 ink glyphs: each bit is one game pixel, never a scaled font.
const GLYPHS := {
	"A": [2,5,7,5,5], "B": [6,5,6,5,6], "C": [3,4,4,4,3],
	"D": [6,5,5,5,6], "E": [7,4,6,4,7], "F": [7,4,6,4,4],
	"G": [3,4,5,5,3], "H": [5,5,7,5,5], "I": [7,2,2,2,7],
	"J": [1,1,1,5,2], "K": [5,5,6,5,5], "L": [4,4,4,4,7],
	"M": [5,7,7,5,5], "N": [9,13,11,9,9], "O": [2,5,5,5,2],
	"P": [6,5,6,4,4], "Q": [2,5,5,3,1], "R": [6,5,6,5,5],
	"S": [3,4,2,1,6], "T": [7,2,2,2,2], "U": [5,5,5,5,7],
	"V": [5,5,5,5,2], "W": [5,5,7,7,5], "X": [5,5,2,5,5],
	"Y": [5,5,2,2,2], "Z": [7,1,2,4,7], ".": [0,0,0,0,2],
	":": [0,2,0,2,0], "'": [2,2,0,0,0], "-": [0,0,7,0,0],
	" ": [0,0,0,0,0],
}
const MIN_WIDTH := [26, 36, 28, 30, 38, 40, 80, 80, 54]
const INK := Color("27241f")
const ACCENT := Color("77504a")
## Physical mounting and corner treatment, independent of the slogan.
@export_enum("Folded left", "Folded right", "Taped", "Stapled") var paper_style := 0:
	set(value):
		paper_style = value
		queue_redraw()
## Chooses one of the nine approved designs.
@export_range(0, 8) var design := 0:
	set(value):
		design = value
		queue_redraw()
## Size in game pixels; placement keeps the whole paper on its wall surface.
@export var paper_size := Vector2(28, 40):
	set(value):
		paper_size = value
		queue_redraw()

func _draw() -> void:
	_draw_paper()
	match design:
		0:
			_text("DEAD", 6)
			_text("LINES:", 13)
			_rule(21)
			_text("NOW", 25, 2)
		1:
			_text("CLIMB TO", 6)
			_text("SUCCESS", 14)
			# A formal printed notice, like the reference: headline and small
			# gray copy rules above a turned-up corner, rather than an icon.
			for i in 4:
				var lengths := [0.82, 1.0, 0.68, 0.88]
				draw_rect(Rect2(5, 25 + i * 3, floorf((paper_size.x - 10) * lengths[i]), 1), _paper_color().darkened(0.38))
			draw_rect(Rect2(paper_size.x - 13, paper_size.y - 6, 7, 1), _paper_color().darkened(0.32))
		2:
			_text("EVERY", 6)
			_text("SECOND", 14)
			_text("COUNTS", 22)
			_icon(31)
		3:
			_icon(6)
			_text("SMILE.", 20)
			_text("YOU'RE", 28)
			_text("AT WORK", 35)
		4:
			_icon(6)
			_text("TEAMWORK", 21)
			_rule(28)
			_text("MEANS", 32)
			_text("OVERTIME", 39)
		5:
			_icon(6)
			_text("YOUR BEST", 21)
			_text("IS THE", 29)
			_text("MINIMUM", 37)
		6:
			_text("RISE. WORK. REPEAT.", 7)
			_rule(16)
		7:
			_text("PRODUCTIVITY", 5)
			_text("IS HAPPINESS", 13)
		8:
			_text("THINK OF THE", 6)
			_text("SHAREHOLDERS", 14)
			_rule(22)
			_icon(27)

func _draw_paper() -> void:
	var paper := _paper_color()
	var w := int(paper_size.x)
	var h := int(paper_size.y)
	var folded := paper_style < 2
	var corner := 6 if folded else 0
	# The silhouette actually loses its corner. No opaque rectangle remains
	# below the fold. The one-pixel contact shadow follows this same edge.
	for y in h:
		var cut := maxi(0, y - (h - corner)) if folded else 0
		var left := cut if paper_style == 0 else 0
		var right := w - (cut if paper_style == 1 else 0)
		draw_rect(Rect2(left + 1, y + 1, right - left, 1), Color(0.035, 0.045, 0.05, 0.35))
	for y in h:
		var cut := maxi(0, y - (h - corner)) if folded else 0
		var left := cut if paper_style == 0 else 0
		var right := w - (cut if paper_style == 1 else 0)
		var shade := paper.darkened(0.035 if y > h * 0.66 else 0.0)
		if y == 0 or y == h - 1: shade = paper.darkened(0.22)
		draw_rect(Rect2(left, y, right - left, 1), shade)
		draw_rect(Rect2(left, y, 1, 1), paper.darkened(0.19))
		draw_rect(Rect2(right - 1, y, 1, 1), paper.darkened(0.26))
	if folded:
		# The reverse face is lighter, with a darker seam where it bends back.
		for row in corner:
			var xx := row if paper_style == 0 else w - corner
			draw_rect(Rect2(xx, h - corner + row, corner - row, 1), paper.lightened(0.13))
			var seam := corner if paper_style == 0 else w - corner - 1
			draw_rect(Rect2(seam, h - corner + row, 1, 1), paper.darkened(0.28))
		draw_rect(Rect2(3, 3, w - 6, 1), paper.darkened(0.22))
		for x in [3, w - 5]:
			draw_rect(Rect2(x, 2, 2, 1), paper.lightened(0.23))
			draw_rect(Rect2(x + 1, 3, 1, 1), paper.darkened(0.45))
	elif paper_style == 2:
		# Matte tape straddles paper and wall; no long drop shadow or glow.
		for x in [4, w - 11]:
			draw_rect(Rect2(x, -1, 7, 3), Color(0.55, 0.55, 0.46, 0.8))
			draw_rect(Rect2(x + 1, 0, 5, 1), Color(0.66, 0.65, 0.55, 0.45))
	else:
		for x in [3, w - 6]:
			draw_rect(Rect2(x, 2, 3, 1), paper.lightened(0.18))
			draw_rect(Rect2(x, 3, 1, 1), paper.darkened(0.45))
			draw_rect(Rect2(x + 2, 3, 1, 1), paper.darkened(0.45))

func _paper_color() -> Color:
	if paper_style < 2: return Color("a6afac")
	if design in [1, 5, 7]: return Color("a5aaa3")
	if design == 3: return Color("b0aa88")
	return Color("ada795")

func _text(line: String, y: int, pixel_size := 1) -> void:
	var width := -pixel_size
	for letter in line:
		width += (5 if letter == "N" else 4) * pixel_size
	var left := floori((paper_size.x - width) / 2.0)
	for letter in line:
		var rows: Array = GLYPHS[letter]
		var columns := 4 if letter == "N" else 3
		for row in 5:
			for column in columns:
				if int(rows[row]) & (1 << (columns - 1 - column)):
					draw_rect(Rect2(left + column * pixel_size, y + row * pixel_size,
						pixel_size, pixel_size), INK)
		left += (columns + 1) * pixel_size

func _rule(y: int) -> void:
	draw_rect(Rect2(5, y, paper_size.x - 10, 1), ACCENT)

func _icon(y: int) -> void:
	var x := floori(paper_size.x / 2.0) - 6
	match design:
		1: # Stairs and a rising arrow.
			for i in 3:
				draw_rect(Rect2(x + i * 4, y + 8 - i * 3, 4, 3 + i * 3), INK)
			draw_line(Vector2(x, y + 5), Vector2(x + 8, y - 1), ACCENT, 1, false)
			draw_rect(Rect2(x + 5, y - 1, 4, 1), ACCENT)
			draw_rect(Rect2(x + 8, y - 1, 1, 4), ACCENT)
		2: # Square-edged clock face.
			draw_rect(Rect2(x + 1, y, 11, 11), INK)
			draw_rect(Rect2(x + 2, y + 1, 9, 9), _paper_color())
			draw_rect(Rect2(x + 6, y + 2, 1, 4), INK)
			draw_rect(Rect2(x + 6, y + 5, 3, 1), INK)
		3:
			draw_rect(Rect2(x + 1, y, 11, 11), INK)
			draw_rect(Rect2(x + 2, y + 1, 9, 9), _paper_color())
			for eye in [4, 8]: draw_rect(Rect2(x + eye, y + 3, 1, 2), INK)
			draw_rect(Rect2(x + 4, y + 7, 5, 1), INK)
			for edge in [3, 9]: draw_rect(Rect2(x + edge, y + 6, 1, 1), INK)
		4:
			for i in 3:
				var top := y + (0 if i == 1 else 3)
				draw_rect(Rect2(x - 2 + i * 5, top, 3, 3), INK)
				draw_rect(Rect2(x - 3 + i * 5, top + 4, 5, 6), INK)
		5:
			draw_rect(Rect2(x + 2, y, 9, 5), INK)
			draw_rect(Rect2(x + 4, y + 5, 5, 2), INK)
			draw_rect(Rect2(x + 6, y + 7, 1, 2), INK)
			draw_rect(Rect2(x + 3, y + 9, 7, 2), INK)
			draw_rect(Rect2(x, y + 1, 2, 3), ACCENT)
			draw_rect(Rect2(x + 11, y + 1, 2, 3), ACCENT)
		8:
			for i in 4:
				draw_rect(Rect2(x - 4 + i * 5, y + 9 - i * 2, 3, 3 + i * 2), ACCENT)
