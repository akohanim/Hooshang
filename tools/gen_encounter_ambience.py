"""Seeded pond breeze, crickets and dawn birds; stdlib, no external recordings.
Writes native Godot resources so playback does not depend on a WAV import.
"""
from pathlib import Path
import math
import random
import struct
import subprocess
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050
COUNT = RATE * 12
OUT = ROOT / 'assets/audio/act2_encounter'


def generate(kind):
    rng = random.Random('act2:' + kind)
    samples = [0.0] * COUNT
    if kind == 'breeze':
        low = 0.0
        for i in range(COUNT):
            low += 0.025 * (rng.uniform(-1, 1) - low)
            samples[i] = low * (1.3 + 0.4 * math.sin(math.tau * i / COUNT * 3))
    else:
        for _ in range(45 if kind == 'crickets' else 14):
            start = rng.randrange(COUNT)
            length = int(RATE * rng.uniform(0.07, 0.16 if kind == 'crickets' else 0.32))
            freq = rng.uniform(3700, 4500) if kind == 'crickets' else rng.uniform(1800, 2900)
            phase = 0.0
            for j in range(length):
                t = j / RATE
                sweep = 100 * math.sin(t * 60) if kind == 'crickets' else 900 * math.sin(t * 12)
                phase += math.tau * (freq + sweep) / RATE
                envelope = math.sin(math.pi * j / length) ** 2
                pulse = (0.6 + 0.4 * math.sin(t * 180)) if kind == 'crickets' else 1
                samples[(start + j) % COUNT] += 0.23 * envelope * pulse * math.sin(phase)
    blend = RATE // 10
    for i in range(blend):
        mix = i / (blend - 1)
        samples[-blend + i] = samples[-blend + i] * (1 - mix) + samples[i] * mix
    return samples[blend:]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temp:
        statements = []
        for kind in ('breeze', 'crickets', 'birds'):
            path = Path(temp) / (kind + '.wav')
            with wave.open(str(path), 'wb') as out:
                out.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
                out.writeframes(b''.join(struct.pack('<h', round(max(-1, min(1, s)) * 32767)) for s in generate(kind)))
            statements.extend([
                f'\tvar {kind} := AudioStreamWAV.load_from_file("{path}")',
                f'\t{kind}.loop_mode = AudioStreamWAV.LOOP_FORWARD',
                f'\t{kind}.loop_end = {kind}.data.size() / 2',
                f'\tassert(ResourceSaver.save({kind}, "res://assets/audio/act2_encounter/{kind}.res") == OK)',
            ])
        pack = Path(temp) / 'pack.gd'
        pack.write_text('extends SceneTree\nfunc _initialize() -> void:\n' + '\n'.join(statements) + '\n\tquit()\n')
        subprocess.run(['/Applications/Godot.app/Contents/MacOS/Godot', '--headless', '--path', str(ROOT), '--script', str(pack)], check=True)


if __name__ == '__main__':
    main()
