"""Render a somber Shur Circuit Climb reprise; preserve the original recording.

Requires ffmpeg and numpy. Lower the score three semitones, relax its tempo by
7.5%, soften the bright percussion, and add a quiet octave shadow and distant
stereo echoes. This is an alternate mix of the supplied score, not a new melody.
The tail crossfades into the head before Ogg encoding for seamless repeat.
"""
from pathlib import Path
import json
import subprocess
import tempfile
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/music/shur_circuit_climb.mp3"
DEST = ROOT / "assets/music/darkshang_shur_requiem.ogg"
RATE = 48000


def main():
    pitch = 2 ** (-3 / 12)
    graph = (
        f"[0:a]asetrate={RATE * pitch},aresample={RATE},"
        f"atempo={0.925 / pitch},highpass=f=32,lowpass=f=6100,"
        "equalizer=f=2600:t=q:w=0.8:g=-3,asplit=2[body][shadow];"
        "[shadow]asetrate=24000,aresample=48000,atempo=2,"
        "lowpass=f=170,volume=0.13[sub];"
        "[body][sub]amix=inputs=2:normalize=0:duration=first,"
        "aecho=0.8:0.9:311|467|733|1127:0.10|0.075|0.055|0.035[out]"
    )
    with tempfile.TemporaryDirectory(prefix="darkshang-score-") as tmp:
        pcm = Path(tmp) / "reprise.f32"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(SOURCE),
                        "-filter_complex", graph, "-map", "[out]", "-ar", str(RATE),
                        "-ac", "2", "-f", "f32le", str(pcm)], check=True)
        samples = np.fromfile(pcm, dtype="<f4").reshape(-1, 2)
        overlap = int(RATE * 1.5)
        mix = np.linspace(0, 1, overlap, dtype=np.float32)[:, None]
        # Linear overlap preserves level, including correlated sustained notes.
        samples[-overlap:] = samples[-overlap:] * (1 - mix) + samples[:overlap] * mix
        samples = samples[overlap:]
        samples *= (10 ** (-1.5 / 20)) / max(float(np.max(np.abs(samples))), 1e-8)
        samples.astype("<f4").tofile(pcm)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE),
                        "-ac", "2", "-i", str(pcm), "-c:a", "libvorbis", "-q:a", "6",
                        "-metadata", "title=Darkshang — Shur Requiem",
                        "-metadata", "comment=Somber reprise of Shur Circuit Climb",
                        str(DEST)], check=True)
    report = dict(duration_seconds=round(len(samples) / RATE, 3),
                  peak_dbfs=round(20 * np.log10(float(np.max(np.abs(samples)))), 2),
                  rms_dbfs=round(20 * np.log10(float(np.sqrt(np.mean(samples ** 2)))), 2),
                  boundary_step=float(np.max(np.abs(samples[0] - samples[-1]))),
                  pitch_semitones=-3, tempo_ratio=0.925, crossfade_seconds=1.5)
    print(json.dumps(report, indent=2))
    print(DEST)


if __name__ == "__main__":
    main()
