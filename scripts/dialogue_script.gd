class_name DialogueScript
## A written script — the multiline String an LDtk trigger carries — turned into
## ordered `[{text, face}]` beats: one spoken line per line of text, each
## carrying whichever portrait state is in force when it is reached.
##
## Pulled out of LdtkRumiTrigger (which still calls it, and whose
## tests/rumi_script_test.gd still pins it) once Jamshid needed exactly the same
## reading. The parsing is the part that can go quietly wrong, and the failure it
## makes is a STAGE DIRECTION PRINTED ON SCREEN as though the speaker said it —
## CLAUDE.md's dialogue rules call that out specifically, so two speakers must
## not get two chances to be right about it.
##
## A line may open with a PORTRAIT STATE in parentheses — `(serene)`, `(joyful)`
## — naming which of the caller's own face table it wears for that line. That is
## the project's dialogue rule and not a shortcut: a parenthetical in a script is
## an instruction to the scene, never words anybody says, so it is read and
## STRIPPED and can never reach the screen as text. The state is sticky, so a
## script that names it once keeps it until it says otherwise, which is how a
## written script reads. An optional leading speaker name and dash are tolerated
## too, so a script can be pasted in exactly as it was written:
##
##     RUMI (serene) — These are the thoughts you would rather not have.
##     You cannot strike them down.[p] There is nothing here to strike.
##
## `[p]` (DialogueBox.PAUSE_MARK) still works inside a line, and is a held breath
## rather than a page break.
##
## Every function here is static and pure, so a test can read a script without
## staging the beat that would play it.


## `text` parsed into [{text, face}], in order.
##
## `faces` is the speaker's own state -> portrait table (Act1Beats.RUMI_FACES,
## Jamshid.FACES, ...), consulted ONLY to warn about a state that has no
## drawing — a named state nobody has art for would otherwise just show no
## portrait, which looks like the art failing to load rather than like a typo.
## `who` names the speaker in that warning.
static func parse(text: String, faces: Dictionary = {}, who := "DialogueScript") -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	var face := ""
	for raw: String in text.split("\n"):
		var line := _drop_heading(raw.strip_edges())
		if line.is_empty():
			continue
		if line.begins_with("("):
			var close := line.find(")")
			if close > 0:
				var state := line.substr(1, close - 1).strip_edges()
				if _is_state(state):
					face = state
					line = _drop_dashes(line.substr(close + 1).strip_edges())
					if not faces.is_empty() and not faces.has(state):
						push_warning("%s: no portrait state '%s'" % [who, state])
		if line.is_empty():
			continue
		beats.append({"text": line, "face": face})
	return beats


## Drop a script's speaker heading ("RUMI — ", "JAMSHID (joyful) — ").
##
## Both halves of the test matter. The heading has to be UPPERCASE, which is how
## a script writes one and is what tells "RUMI" from a line that simply opens on
## a name; and it has to be FOLLOWED by a parenthetical or a dash, so nothing is
## taken off a line that merely starts with a shout.
static func _drop_heading(line: String) -> String:
	var space := line.find(" ")
	if space <= 0:
		return line
	var head := line.substr(0, space)
	if head != head.to_upper() or not _is_state(head.to_lower()):
		return line
	var rest := line.substr(space + 1).strip_edges()
	if rest.begins_with("(") or _starts_with_dash(rest):
		return _drop_dashes(rest)
	return line


## The em dash a script puts between its heading and the words. Written as the
## character rather than an escape on purpose: GDScript and the regex engine
## disagree about \u, and this got that wrong once already.
static func _starts_with_dash(line: String) -> bool:
	return line.begins_with("—") or line.begins_with("–") or line.begins_with("-")


static func _drop_dashes(line: String) -> String:
	var out := line
	while _starts_with_dash(out):
		out = out.substr(1).strip_edges()
	return out


## A bare word a state could be — lowercase letters and underscores, nothing
## else. Keeps a genuine aside like "(he looks away)" from being read as one.
static func _is_state(text: String) -> bool:
	if text.is_empty():
		return false
	for c: String in text:
		if not ((c >= "a" and c <= "z") or c == "_"):
			return false
	return true
