#!/usr/bin/env python3
"""Short synthesized whistle and dry can impact, no external samples."""
import math,random,struct,wave
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'assets/audio/school_story';out.mkdir(parents=True,exist_ok=True)
rng=random.Random(74)
for name,duration in [('whistle',0.48),('clack',0.12)]:
    samples=[]
    for i in range(int(44100*duration)):
        t=i/44100
        if name=='whistle':
            envelope=min(1,t/.018)*min(1,(duration-t)/.065)
            v=math.sin(math.tau*(1850*t+3*math.sin(math.tau*18*t)))*envelope*.42
        else:
            v=(rng.uniform(-1,1)*.6+math.sin(math.tau*1700*t)*.4)*math.exp(-t*55)*.7
        samples.append(struct.pack('<h',int(v*32767)))
    with wave.open(str(out/(name+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(44100);f.writeframes(b''.join(samples))
