extends Node
## Celeste-style dialogue voice: short synthesized syllables, banked per
## speaker+portrait-state and per TIER (passing / emphasized / ending),
## retriggered as DialogueBox's typewriter reveals each character.
##
## The clips themselves are generated, not recorded — tools/gen_voice_blips.py
## synthesizes them from vowel-like formants, one bank per existing portrait
## state, so the "which state is on screen" mapping this needs is exactly the
## key DialogueBox._set_rig/_set_loop already derive from the portrait
## texture's filename ("hooshang_annoyed", "rumi_wistful", ...). Nothing about
## how a beat is written changes.
##
## ONE shared, retriggered AudioStreamPlayer, not a pool per speaker: this
## game shows one speaker at a time (DialogueBox's own doc — future multi-line
## conversations are sequential `await Dialogue.say()` calls), so there is
## never more than one voice needing to play at once.

## Emitted every time a clip actually plays. Nothing in the game consumes this
## yet; it exists so a test can observe what played without reaching into
## private state.
signal blipped(key: String, tier: String, clip_path: String)

const MANIFEST_PATH := "res://assets/voice/manifest.json"
const VOICE_DIR := "res://assets/voice/"

## How far a blip's pitch is nudged per play, as a fraction either way — the
## "performed on a pitch wheel" detail, so two blips of the same clip never
## sound perfectly identical.
const PITCH_JITTER := 0.04

## key ("hooshang_annoyed") -> {tier -> clip count}. A missing or unreadable
## manifest means every key is simply absent, which is silence everywhere —
## the same "dialogue is not worth crashing a run over" rule
## DialogueBox._load_rigs() already follows for portrait rigs.
var _manifest := {}
## (key, tier) -> index of the last clip played from that pool, so the next
## pick can avoid repeating it — "no consecutive duplicate syllables".
var _last_index := {}
var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	var res := load(MANIFEST_PATH)
	if res is JSON and res.data is Dictionary:
		_manifest = res.data


## Play one random clip from `key`'s `tier` pool, retriggering the shared
## player. No-ops silently when `key` or `tier` isn't in the manifest — an
## unknown or absent speaker/state simply has no voice, same as an unrigged
## portrait simply holding still.
func blip(key: String, tier: String = "passing") -> void:
	if key == "" or not _manifest.has(key):
		return
	var pools: Dictionary = _manifest[key]
	if not pools.has(tier):
		return
	var count := int(pools[tier])
	if count <= 0:
		return
	var pool_key := "%s/%s" % [key, tier]
	var index := randi() % count
	if count > 1 and _last_index.get(pool_key, -1) == index:
		index = (index + 1) % count  # one retry, deterministic direction
	_last_index[pool_key] = index

	# assets/voice/<speaker>/<state>/<tier>_<index+1>.wav. key is
	# "<speaker>_<state>", and a STATE name can itself contain an underscore
	# ("warm_open") even though no speaker name does — split on the FIRST
	# underscore only, or "rumi_warm_open" would break into three pieces.
	var parts := key.split("_", true, 1)
	var path := "%s%s/%s/%s_%d.wav" % [VOICE_DIR, parts[0], parts[1], tier, index + 1]

	var stream := load(path)
	if stream == null:
		return
	_player.pitch_scale = 1.0 + randf_range(-PITCH_JITTER, PITCH_JITTER)
	_player.stream = stream
	_player.play()
	blipped.emit(key, tier, path)
