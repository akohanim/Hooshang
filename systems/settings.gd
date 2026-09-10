extends Node
## Player preferences that outlive any one save slot (autoload "Settings").
##
## Turning music off is a device preference, not run progress — it has to stay
## off on the title screen, in a brand new game, and in whichever of
## SaveGame's three slots gets loaded next. So it lives in its own tiny file
## rather than riding along in a save payload (SaveGame's own schema has no
## business knowing a player's audio taste), and applies itself once at boot,
## well before any world's Music node has had a chance to autoplay.
##
## MUTES A BUS, NOT AudioServer WHOLESALE. `default_bus_layout.tres` gives
## every world's Music node its own "Music" bus — see the Layout section's
## note on it. Voice blips, SFX and hazard sounds all stay on Master and keep
## playing with music off, which is the entire reason that bus exists rather
## than this just calling AudioServer.set_bus_mute(0, ...).

signal music_enabled_changed(enabled: bool)

## Where the one preference lives. A plain var, not a const, so a test can
## point it at a throwaway file the same way SaveGame.dir works — a suite run
## must never be able to flip a real player's setting.
var path := "user://settings.json"

var music_enabled := true

var _music_bus := -1


func _ready() -> void:
	_music_bus = AudioServer.get_bus_index("Music")
	_load()
	_apply()


## The pause menu's MUSIC row calls this rather than assigning the var
## directly, so the bus and the file always agree with what's on screen.
func set_music_enabled(enabled: bool) -> void:
	if enabled == music_enabled:
		return
	music_enabled = enabled
	_apply()
	_save()
	music_enabled_changed.emit(music_enabled)


func _apply() -> void:
	if _music_bus >= 0:
		AudioServer.set_bus_mute(_music_bus, not music_enabled)


func _load() -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		music_enabled = bool((parsed as Dictionary).get("music_enabled", true))


func _save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Settings: cannot write %s (error %d)." % [path, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify({"music_enabled": music_enabled}))
	f.close()
