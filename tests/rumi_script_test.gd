extends Node
## The Rumi trigger's SCRIPT parsing: a written script becomes spoken lines.
##
## This exists because every way it can fail is quiet. A stage direction that is
## not stripped is printed on screen as though Rumi said the word "(serene)". A
## state that is read but not applied leaves the right words on the wrong face.
## A `[p]` mistaken for a direction turns a held breath into nothing. None of
## those raise anything; they just ship.
##
## Run:  godot --headless res://tests/rumi_script_test.tscn

const TRIGGER := preload("res://scripts/ldtk_rumi_trigger.gd")

## The Vipassana 1 script, exactly as it was written.
const VIPASSANA := """RUMI (serene) — These are the thoughts you would rather not have, Hooshang jaan.
RUMI (serene) — You cannot strike them down.[p] There is nothing here to strike.
RUMI (serene) — Let it come, watch it travel,[p] and step where it is not."""

var failures: Array[String] = []


func _ready() -> void:
	_run()


func _run() -> void:
	var beats := _parse(VIPASSANA)
	_check(beats.size() == 3, "the script is three lines  [%d]" % beats.size())

	# --- nothing that is not speech reaches the screen -----------------------
	var leaked := []
	for b: Dictionary in beats:
		var t: String = b["text"]
		if t.contains("(") or t.contains("RUMI") or t.begins_with("—") \
				or t.begins_with("-"):
			leaked.append(t)
	_check(leaked.is_empty(),
		"no heading, dash or stage direction survives into the words  %s" % str(leaked))

	# The exact words, so a parser that stripped too much fails here too.
	var want := [
		"These are the thoughts you would rather not have, Hooshang jaan.",
		"You cannot strike them down.[p] There is nothing here to strike.",
		"Let it come, watch it travel,[p] and step where it is not.",
	]
	for i in mini(beats.size(), want.size()):
		_check(beats[i]["text"] == want[i],
			"line %d is exactly what he says  [%s]" % [i + 1, beats[i]["text"]])

	# --- the direction was READ, not merely deleted --------------------------
	var faces := []
	for b: Dictionary in beats:
		faces.append(b["face"])
	_check(faces == ["serene", "serene", "serene"],
		"every line wears the state its direction named  %s" % str(faces))
	# Not vacuous: an unnamed state must NOT come out "serene".
	var bare := _parse("Just words.")
	_check(bare.size() == 1 and bare[0]["face"] == "",
		"...and a line with no direction names no face  [%s]"
			% (bare[0]["face"] if not bare.is_empty() else "?"))

	# --- the held breath is not a direction ----------------------------------
	var breaths := 0
	for b: Dictionary in beats:
		if (b["text"] as String).contains(DialogueBox.PAUSE_MARK):
			breaths += 1
	_check(breaths == 2,
		"both held breaths survive parsing  [%d of 2]" % breaths)

	# --- the state is sticky, the way a script reads -------------------------
	var sticky := _parse("(wistful) First.\nSecond.\n(urgent) Third.")
	var sf := []
	for b: Dictionary in sticky:
		sf.append(b["face"])
	_check(sf == ["wistful", "wistful", "urgent"],
		"a state carries to the lines after it until changed  %s" % str(sf))

	# --- a capitalised first word is not a speaker heading -------------------
	var plain := _parse("Hooshang jaan, listen.")
	_check(plain.size() == 1 and plain[0]["text"] == "Hooshang jaan, listen.",
		"a line that merely starts with a name keeps it  [%s]"
			% (plain[0]["text"] if not plain.is_empty() else "?"))

	# --- blank lines are spacing, not empty presses --------------------------
	var spaced := _parse("(serene) One.\n\n\nTwo.")
	_check(spaced.size() == 2,
		"blank lines between beats are not spoken  [%d]" % spaced.size())

	if failures.is_empty():
		print("RUMI SCRIPT TEST: ALL PASS")
	else:
		print("RUMI SCRIPT TEST: %d FAILURE(S)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _parse(text: String) -> Array[Dictionary]:
	var t: LdtkRumiTrigger = TRIGGER.new()
	t.dialogue_line = text
	var beats := t.script_beats()
	t.free()
	return beats


func _check(cond: bool, name: String) -> void:
	print(("  PASS  " if cond else "  FAIL  ") + name)
	if not cond:
		failures.append(name)
