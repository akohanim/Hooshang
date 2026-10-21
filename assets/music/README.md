# Title screen

`menu_theme.ogg` is the title cue (`MenuMusic` in `scenes/ui/MainMenu.tscn`, on
the Music bus at -15 dB): an ElevenLabs Music track composed for the menu —
ney melody in Dashti colour over santur and setar, 76 BPM, warm and quiet, only
a few soft daf touches. It plays its own 7.2 s swell up out of silence ONCE,
then loops a 21-bar, 66 s body (`loop_offset` in its `.import` jumps back past
the intro). Generated, looped and levelled as described in
`assets/audio/elevenlabs_v2/README.md`.

`menu_shur.ogg` (built by `python3 tools/build_menu_shur.py` from the garden
score plus a sparse darbuka hit) is the cue it replaced, kept for comparison.

# Act I score

`shur_circuit_climb.mp3` is the original office score, preserved unchanged.
`darkshang_shur_requiem.ogg` was a somber alternate mix of that recording for
Darkshang's Levels 14–25; it is now superseded by `darkshang_theme.ogg` (an
ElevenLabs chase score, see `assets/audio/elevenlabs_v2/README.md`) and kept
for comparison only. It retains the melody, lowers the register three
semitones, eases the tempo by 7.5%, softens the bright percussion, and adds a
quiet octave shadow and distant echoes. It is a reprise, not a new composition.

Regenerate with `python3 tools/gen_darkshang_music.py` (ffmpeg and numpy).
The 3:14 stereo Ogg has a 1.5-second tail/head overlap, with looping enabled in
its import settings. The rendered master peaks at -1.5 dBFS.

`Music` in `ldtk/Act1World.tscn` uses `scripts/act1_music.gd`: two continuous
looping streams, blended over two seconds when entering/leaving the chase.
Crossing rooms or dying never resets either stream. Homecoming in Level 26
restores the original arrangement. Dialogue ducking and the Music setting
apply to the complete mix. Check with `tests/darkshang_music_test.tscn`.

# Act II score

`source/sunlit_garden_path.mp3` is the original 60-second "Sunlit Garden Path"
(four 15s sections: A Garden Introduction, Exploring Neighborhood Ponds,
Playful Wonder, Loop Coda), kept unchanged and hidden from Godot by `.gdignore`.
`tools/gen_act2_garden_music.py` cuts it into five Ogg cues (`garden_*.ogg`).
It measures 100.0 BPM in 4/4, so 15s is 25 beats — six bars and a beat — and a
raw 15s section cannot loop without the bar lurching. Each loop is therefore cut
on its own section's downbeat to whole bars (ponds 5 bars, wonder 6), with a
one-beat equal-power crossfade at the seam; the intro is the head of the
recording up to the ponds loop, so it runs into it with no seam at all.
`garden_rest.ogg` is one silent bar.

`Music` in `ldtk/Act2World.tscn` uses `scripts/act2_music.gd`: one
AudioStreamInteractive, every change on the next bar with a one-bar crossfade.
Intro then ponds in the opening rooms (0–2), Playful Wonder through the sky
gardens (3–13) with ponds again in the breather room 8, the coda once on
leaving the gardens (14), the prison theme in the prison hub and wings, and
silence for the gatehouse, escape and finale. The Jamshid night encounter rests the score and resumes it at dawn.
Silence is a clip, not a volume fade, because LdtkWorld's dialogue duck owns
the node's volume. Check with `tests/act2_music_test.tscn`.

# Act II prison and Act I Darkshang (ElevenLabs)

`prison_theme.ogg` plays in Act 2's prison hub and wings as a sixth cue of
`act2_music.gd`'s interactive stream (counted in its own 60 BPM).
`darkshang_theme.ogg` is now Act 1's `chase_stream`. Both are generated, looped
and levelled as described in `assets/audio/elevenlabs_v2/README.md`.

# Act III score — "The Sea"

Seven synthesised cues, all made by `python3 tools/gen_act3_sea_music.py`
(numpy + ffmpeg, deterministic, no source recording — the voice-blip recipe).
One theme in Dastgah-e Shur on D, with its true E koron (50 cents flat), travels
the act the way the colour does (`docs/act3/ACT3_DESIGN.md`):

| cue | plays | what it is |
|---|---|---|
| `sea_shore.ogg` | Ch I, loop | surf, and the theme in single santur notes with long silences — black and white |
| `sea_deep.ogg` | Ch II, loop | a D drone opens; santur arpeggios; phrase A on a breathy ney |
| `sea_wreck.ogg` | Ch III, loop | a flickering tube hum; the theme on a muffled, wobbling electric piano |
| `sea_reef.ogg` | Ch IV, loop | glass bells, shimmering pads, the whole melody (phrases A + B) |
| `sea_trench.ogg` | Ch V chase, loop | a heartbeat that keeps getting heavier, a D/E-flat santur tremolo, swells from below |
| `sea_floor.ogg` | the floor, once | one held chord in the light, then the third arrives and the theme turns to Mahur (major) |
| `sea_dawn.ogg` | the real sea, loop | the full theme in Mahur, warm |

Instruments are additive/FM: a santur of doubled, slightly detuned inharmonic
courses with a hammer click; a ney (sine + soft octave, blooming vibrato, breath
noise); FM glass bells; detuned-saw pads; a convolution hall from decaying noise.
Every loop is rendered with 6 s of tail that is folded back onto its head, so a
note ringing past the seam keeps ringing into the next pass (measured seam
jumps 0.001–0.013). `scripts/act3/act3_music.gd` (on `ldtk/Act3World.tscn`'s
`Music`, Music bus, -10 dB) switches cue by chapter with 3 s crossfades; the
floor cue plays once per arrival, and the office at dawn is silent.

Act III's three small sound effects — `bubble`, `jelly`, `memory` — are made by
`python3 tools/gen_act3_sfx.py` into `assets/audio/act3/` and registered in
`systems/sfx.gd`'s `ACT3_CUES`.
