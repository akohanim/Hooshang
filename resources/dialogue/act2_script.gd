class_name Act2Script
extends Resource
## Verbatim spoken lines compiled from docs/story/act2_author_script.md.
@export var scenes: Dictionary = {}


## Index of the first line in `scene` whose words begin with `opening`.
##
## Staging between two lines (a whistle, a flash of memory, a can falling) is
## pinned to the line it comes BEFORE by that line's opening words, not by its
## position: the author's script changes, and a line added or cut earlier in a
## scene would otherwise slide every later beat onto the wrong words in silence.
## A missing anchor is an error, not a skipped beat — rewording the line a beat
## hangs off means moving the beat with it.
func cue(scene: String, opening: String) -> int:
	var lines: Array = scenes.get(scene, [])
	for i in lines.size():
		if str(lines[i].text).begins_with(opening):
			return i
	push_error("Act2Script: no line in '%s' begins \"%s\"" % [scene, opening])
	return -1
