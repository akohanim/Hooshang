"""Build a warm, quiet menu loop with sparse ElevenLabs darbuka accents.

The garden score provides the neutral melody. A single soft drum hit is
isolated from the ElevenLabs oud and darbuka recording and placed only twice
per twelve-second phrase. Requires ffmpeg, numpy and scipy.
"""
from pathlib import Path
import subprocess

import numpy as np
from scipy import ndimage, signal

ROOT = Path(__file__).resolve().parents[1]
BED = ROOT / "assets/music/garden_ponds.ogg"
DRUM_SOURCE = ROOT / "assets/audio/elevenlabs_v2/source/darkshang_theme.mp3"
OUT = ROOT / "assets/music/menu_shur.ogg"
SR = 22050


def decode(path, channels=2):
    raw = subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(path), "-ar", str(SR),
        "-ac", str(channels), "-f", "f32le", "-",
    ])
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, channels).copy()


phrase = decode(BED)
phrase = signal.sosfiltfilt(signal.butter(2, 5000, fs=SR, output="sos"),
                               phrase, axis=0).astype(np.float32)
music = np.tile(phrase, (5, 1))  # one minute, made of complete musical phrases

# Separate quick drum transients from the pitched oud. Pick one clear attack,
# then let silence between accents keep the menu gentle and unhurried.
source = decode(DRUM_SOURCE, 1)[:20 * SR, 0]
_, _, spectrum = signal.stft(source, SR, nperseg=1024, noverlap=768)
mag = np.abs(spectrum)
harmonic = ndimage.median_filter(mag, size=(1, 17))
percussive = ndimage.median_filter(mag, size=(17, 1))
mask = percussive ** 2 / (percussive ** 2 + harmonic ** 2 + 1e-12)
hz = np.arange(len(mask)) * SR / 1024
mask *= ((hz >= 120) & (hz <= 2400))[:, None]
_, isolated = signal.istft(spectrum * mask, SR, nperseg=1024, noverlap=768)
energy = ndimage.uniform_filter1d(isolated ** 2, size=800)
peaks, _ = signal.find_peaks(energy, distance=round(.3 * SR))
peak = max((p for p in peaks if p > .15 * SR), key=lambda p: energy[p])
start = max(0, peak - round(.012 * SR))
hit = isolated[start:start + round(.24 * SR)].copy()
hit *= np.linspace(1, 0, len(hit), dtype=np.float32) ** 1.8
hit /= max(np.max(np.abs(hit)), 1e-6)

for phrase_index in range(5):
    for offset in (2.4, 7.2):
        at = round((phrase_index * 12 + offset) * SR)
        end = min(len(music), at + len(hit))
        music[at:end] += (hit[:end - at] * .018)[:, None]

rms = np.sqrt(np.mean(music.astype(np.float64) ** 2))
music *= 10 ** ((-20 - 20 * np.log10(rms + 1e-12)) / 20)
peak = np.max(np.abs(music))
if peak > .8:
    music *= .8 / peak

subprocess.run([
    "ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR),
    "-ac", "2", "-i", "-", "-c:a", "libvorbis", "-q:a", "6", str(OUT),
], input=music.astype(np.float32).tobytes(), check=True)
print(OUT)
