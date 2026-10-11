# Act II ElevenLabs prototype cues

Generated on 2026-10-09 using ElevenLabs Sound Effects v2, on the free plan.
Credit: elevenlabs.io. These are non-commercial prototype assets; free-plan
generation does not provide a commercial license. Review rights before release:
https://help.elevenlabs.io/hc/en-us/articles/13313564601361

The five cues replace only Act2Audio's key, lock, gate, splash and spray voices.
The previous synthesized assets remain in `../act2_feedback/`. Existing triggers,
per-voice playback levels and cinematic skip handling are preserved.

`source/` keeps the original generated MP3s; `manifest.json` keeps the exact
prompts and generation settings. No credentials are stored in this project.
Masters are mono 44.1 kHz, 16-bit WAV: initial silence removed at -45 dB,
lengths kept to the previous scene cues (0.55, 0.17, 0.8, 1.2, 4.1 seconds),
peak normalized to -3 dBFS before 3 ms attack / 25 ms release fades.
The game uses native `.res` copies, as the existing encounter ambience does.
Repack edited WAVs with:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/import_act2_elevenlabs.gd
```

The one-minute music preview, **Sunlit Garden Path**, is saved at:
https://elevenlabs.io/app/music/project/KCM5dxusPqFHw6b6Ic32?selectedSongId=gA4a7xXPQsifSqM5S4yj

Music download was blocked by the free-plan upgrade dialog. No background
track is installed yet. Once downloadable, integrate a looping `Music` player
on Act2World's root using the Music bus and existing dialogue ducking.
