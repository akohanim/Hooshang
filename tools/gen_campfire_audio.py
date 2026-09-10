"""Deterministic, seamless low fire roar with scattered wood crackles (stdlib)."""
from pathlib import Path
import math
import random
import struct
import wave


def main():
    rate, seconds = 22050, 10
    rng = random.Random(824)
    count = rate * seconds
    samples = []
    low = 0.0
    for i in range(count):
        low += 0.045 * (rng.uniform(-1, 1) - low)
        breath = 0.75 + 0.15 * math.sin(2 * math.pi * i / count * 3)
        samples.append(low * 1.7 * breath + rng.uniform(-0.025, 0.025))
    for _ in range(75):
        start = rng.randrange(count)
        length = rng.randrange(90, 1300)
        strength = rng.uniform(0.08, 0.32)
        for j in range(length):
            samples[(start + j) % count] += rng.uniform(-1, 1) * strength * math.exp(-6 * j / length)
    # Blend the tail into the head, then loop from the end of that head segment.
    blend = 2205
    for i in range(blend):
        mix = i / (blend - 1)
        samples[count - blend + i] = samples[count - blend + i] * (1 - mix) + samples[i] * mix
    samples = samples[blend:]
    path = Path(__file__).resolve().parents[1] / 'assets/props/campfire/campfire_loop.wav'
    with wave.open(str(path), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x)) * 32767)) for x in samples))
    # A native resource keeps the sound available in exported builds, where
    # importing a WAV can remove its raw filesystem path.
    script = path.with_name("pack_audio.gd")
    script.write_text('extends SceneTree\nfunc _initialize() -> void:\n'
                      '\tvar sound := AudioStreamWAV.load_from_file("res://assets/props/campfire/campfire_loop.wav")\n'
                      '\tsound.loop_mode = AudioStreamWAV.LOOP_FORWARD\n'
                      '\tsound.loop_end = sound.data.size() / 2\n'
                      '\tassert(ResourceSaver.save(sound, "res://assets/props/campfire/campfire_loop.res") == OK)\n'
                      '\tquit()\n')
    import os
    import subprocess
    try:
        subprocess.run([os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot'),
                        '--headless', '--path', str(path.parents[3]),
                        '--log-file', '/tmp/campfire-audio-pack.log', '--script', str(script)], check=True)
    finally:
        script.unlink(missing_ok=True)
    print(path)


if __name__ == '__main__':
    main()
