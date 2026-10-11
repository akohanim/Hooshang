#!/usr/bin/env python3
"""Deterministic, sample-free Act 2 interaction foley. Regenerates WAV sources."""
import math,random,struct,wave,json
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]/'assets/audio/act2_feedback';OUT.mkdir(parents=True,exist_ok=True)
RATE=44100
report={}
for name,duration in [('key',.55),('lock',.17),('gate',.8),('splash',1.2),('spray',4.1)]:
 rng=random.Random(231+len(name));samples=[];low=0;prev=0
 for i in range(int(RATE*duration)):
  t=i/RATE;n=rng.uniform(-1,1);low+=.12*(n-low)
  fade=min(1,t/.012)*min(1,(duration-t)/.045)
  if name=='key':
   v=0
   for start,freq in [(0,660),(.11,990)]:
    u=t-start
    if u>=0:v+=(math.sin(math.tau*freq*u)+.2*math.sin(math.tau*freq*2.76*u))*math.exp(-u*10)*min(1,u/.006)*.34
  elif name=='lock':v=(.55*n+.45*math.sin(math.tau*640*t))*math.exp(-t*45)*.6
  elif name=='gate':v=(low*.8+math.sin(math.tau*(180*t+12*t*t))*.08)*(math.sin(math.pi*t/duration)**2)*.7
  elif name=='splash':v=(low*1.7+(n-low)*.16)*math.exp(-t*3.7)*(.8+.2*math.sin(t*43))
  else:v=(n-low)*.18*(.82+.1*math.sin(t*13)+.08*math.sin(t*29))
  samples.append(max(-.9,min(.9,v*fade)))
 with wave.open(str(OUT/(name+'.wav')),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(b''.join(struct.pack('<h',round(v*32767)) for v in samples))
 report[name]={'seconds':duration,'peak':max(abs(x) for x in samples),'rms':(sum(x*x for x in samples)/len(samples))**.5}
(OUT/'levels.json').write_text(json.dumps(report,indent=2)+'\n')
