# Act I score

`shur_circuit_climb.mp3` is the original office score, preserved unchanged.
`darkshang_shur_requiem.ogg` is a somber alternate mix of that recording for
Darkshang's Levels 14–25. It retains the melody, lowers the register three
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
