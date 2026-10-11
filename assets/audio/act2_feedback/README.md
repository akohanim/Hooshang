# Act 2 interaction foley

Original deterministic synthesis, with no external recordings or music samples.
Rebuild using `python3 tools/gen_act2_feedback.py`; `levels.json` records source
peak/RMS values. Playback levels live in `Act2Audio.tscn`, independently editable.

- Key: two soft metallic tones; first collection only.
- Lock: short dry mechanism click, once per inserted key.
- Gate: lower filtered scrape when the cage opens.
- Splash: filtered impact and settling water at the full farewell's pond return.
- Spray: restrained air hiss during the four-second painting stroke.

All files are mono 44.1kHz/16-bit PCM. Endpoints are faded to avoid clicks. The
scene keeps separate voices, so a pickup cannot cut off a lock/cage cue. Spray
and splash stop when their cinematic ends or is skipped; loaded completion
states trigger neither. No global audio bus or Act 1 cue is changed.

`tests/act2_audio_preview.tscn` records an in-engine cue audition at normal
speed. It is not a recording of the complete gameplay mix. Final listening
balance and a finished finale score remain part of presentation review.
