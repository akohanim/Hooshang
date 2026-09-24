"""Original short, quiet synthesized feedback for spring release and rug boarding."""
import math,struct,wave
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'assets/audio/traversal'
def write(name,duration,kind):
 rate=22050;data=[];phase=0
 for i in range(int(rate*duration)):
  t=i/rate;u=t/duration
  if kind=='spring':
   phase+=2*math.pi*(170+460*math.exp(-t*25))/rate
   sample=(math.sin(phase)+.18*math.sin(phase*2))*math.exp(-t*23)
  else:sample=(math.sin(2*math.pi*660*t)+.4*math.sin(2*math.pi*990*t))*math.exp(-t*15)
  sample*=min(1,t/.003)*min(1,(duration-t)/.012)*.45
  data.append(struct.pack('<h',int(max(-1,min(1,sample))*32767)))
 with wave.open(str(out/(name+'.wav')),'wb') as f:f.setparams((1,2,rate,len(data),'NONE','not compressed'));f.writeframes(b''.join(data))
write('spring',.20,'spring');write('carpet_board',.32,'bell')
