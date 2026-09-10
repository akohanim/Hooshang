"""Pack connected body silhouettes with uniform scale and stable anchors."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy.ndimage import label,find_objects
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/characters/hooshang_child/act2'
ROWS={'locomotion':[('idle',0,300),('run',300,555),('jump',555,819),('fall',819,1073)],'traversal':[('dash',0,210),('wall_slide',210,450),('wall_jump',450,665),('climb',665,948)],'water_rest':[('swim',0,220),('swim_idle',220,430),('exit_water',430,690),('sit',690,948)]}
ORDER={'idle':[0,1,2,3,4,5,6,5,4,2,1],'run':[0,1,2,3,4,5,6],'jump':[0,1,2,3,4,5,6],'fall':[0,1,2,3,4,5,4,3,2,1],'dash':list(range(7)),'wall_slide':[0,1,2,3,4,5,6,5,4,3,2,1],'wall_jump':[1,2,3,4,5],'climb':[0,1,2,3,4,5,6,5,4,3,2,1],'swim':[0,1,2,3,4,5,4,3,2,1],'swim_idle':[0,1,2,3,4,5,4,3,2,1],'exit_water':list(range(7)),'sit':[0,1,2,3,4,5,6,4,3,2,1],'wall_land':[0]}
FPS=dict(zip(ORDER,[6,12,12,10,35,8,18,12,3.6,1.8,14,6,1]))
def main():
 resources=[]; metadata={}
 for sheet,rows in ROWS.items():
  source=np.array(Image.open(BASE/'sheets'/f'child_hooshang_{sheet}.png').convert('RGBA'))
  for action,y0,y1 in rows:
   pixels=source[y0:y1]; labels,_=label(pixels[:,:,3]>=200)
   bodies=[(b,i) for i,b in enumerate(find_objects(labels),1) if b is not None and np.count_nonzero(labels[b]==i)>1500]
   bodies.sort(key=lambda b:b[0][1].start)
   assert len(bodies)==(6 if action in ('swim','swim_idle') else 7),(action,len(bodies))
   folder=BASE/'packed'/action; folder.mkdir(parents=True,exist_ok=True); metadata[action]=[]
   for frame,(bounds,ident) in enumerate(bodies):
    crop=pixels[bounds].copy(); crop[:,:,3]=np.where(labels[bounds]==ident,255,0)
    rgb=crop[:,:,:3].astype(float)
    hair=(rgb[:,:,2]>rgb[:,:,0]*1.12)&(rgb[:,:,2]>rgb[:,:,1]*1.03)&(rgb[:,:,0]<100)&(rgb[:,:,1]<110)&(rgb[:,:,2]<160)&(crop[:,:,3]>0)
    hair[int(crop.shape[0]*.55):]=False
    head_labels,_=label(hair)
    sizes=np.bincount(head_labels.ravel()); sizes[0]=0
    yy,xx=np.where(head_labels==sizes.argmax()); assert len(xx)>20,action
    # 16px standing height, matching Jamshid, at the player's .39 scale.
    factor=(16/.39)*(96/269)/(xx.max()-xx.min()+1)
    im=Image.fromarray(crop); target=(max(1,round(im.width*factor)),max(1,round(im.height*factor)))
    im=im.resize(target,Image.Resampling.NEAREST); canvas=Image.new('RGBA',(88,88))
    x=round(44-(xx.min()+xx.max())*.5*factor)
    if action in ('swim','swim_idle'):
     # Controller rotates upright source for travel direction.
     im=im.transpose(Image.Transpose.ROTATE_90); x,y=round(44-im.width/2),round(51-im.height/2)
    else:
     # Feet on ONE baseline for every grounded AND airborne pose. player.gd
     # offset-pins the sprite's feet to the bottom of the hitbox, so a frame
     # whose drawn feet float above that baseline reads as the body leaving its
     # own feet. The old y=25 top-align did exactly that for jump/fall/dash/
     # wall_jump: measured, their feet sat 10-15px (canvas) above idle/run's 65,
     # popping the character up ~4-6px on every takeoff and snapping him back
     # down on landing, plus a 7-8px in-flight bob as the tuck changed height.
     # Bottom-aligning the silhouette keeps the lowest point (the feet in every
     # pose) on the baseline, matching the physics body frame to frame.
     y=66-im.height
    assert x>=0 and y>=0 and x+im.width<=88 and y+im.height<=88,(action,frame,target,x,y)
    canvas.alpha_composite(im,(x,y)); path=folder/f'frame_{frame:03d}.png'; canvas.save(path)
    resources.append(f'[ext_resource type="Texture2D" path="res://{path.relative_to(ROOT)}" id="{action}_{frame}"]')
    metadata[action].append({'source_box':[bounds[1].start,y0+bounds[0].start,bounds[1].stop,y0+bounds[0].stop],'size':target,'anchor':[x,y]})
 clips=[]
 for action,order in ORDER.items():
  src='sit' if action=='wall_land' else action
  frames=', '.join('{"duration": 1.0, "texture": ExtResource("%s_%d")}'%(src,i) for i in order)
  loop=action not in ('jump','wall_jump','dash','exit_water','wall_land')
  clips.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s}'%(frames,str(loop).lower(),action,float(FPS[action])))
 (BASE.parent/'act2_frames.tres').write_text('[gd_resource type="SpriteFrames" format=3]\n\n'+'\n'.join(resources)+'\n\n[resource]\nmetadata/child_hooshang = true\nanimations = ['+',\n'.join(clips)+']\n')
 (BASE/'packing.json').write_text(json.dumps(metadata,indent=2)+'\n')
 print('Packed',sum(map(len,metadata.values())),'complete poses.')
if __name__=='__main__': main()
