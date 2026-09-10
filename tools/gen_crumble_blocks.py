"""Crisp 8px beveled crumble stones; three stable variants, not ceiling panels."""
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
def run():
 strip=Image.new('RGBA',(24,8))
 for v in range(3):
  im=Image.new('RGBA',(8,8));d=ImageDraw.Draw(im)
  d.rectangle((0,0,7,6),fill='#85929e');d.line((0,0,6,0),fill='#c4cdd0')
  d.line((0,1,0,5),fill='#a9b8c3');d.line((1,7,6,7),fill='#475363');d.line((7,1,7,6),fill='#526073')
  d.polygon([(1,1),(6,1),(2,5),(1,5)],fill=['#a5b3bd','#b0bcc4','#9eaebc'][v])
  d.line([(5,2),(4,3),(4,4),(2,5)],fill='#5c697c');d.point((5,5),fill='#b7c2c9')
  strip.paste(im,(v*8,0))
 for frame in range(3):
  damaged=strip.copy();ink=ImageDraw.Draw(damaged)
  for v in range(3):
   x=v*8
   if frame>=1: ink.line([(x+4,1),(x+3,2),(x+3,3)],fill='#526073')
   if frame>=2:
    ink.line([(x+3,3),(x+4,4),(x+3,5),(x+3,6)],fill='#394657')
    ink.point((x+6,6),fill='#475363')
  damaged.save(ROOT/f'assets/props/platform/crumble_{frame}.png')
 icon=Image.new('RGBA',(16,16))
 icon.paste(strip.crop((0,0,16,8)),(0,4))
 icon.save(ROOT/'ldtk/art/platform_crumbling.png')
if __name__=='__main__':run()
