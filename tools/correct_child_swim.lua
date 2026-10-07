-- Reference recheck: 24 (4 ticks) -> 26 (8 ticks) -> 22 (glide).
-- The native side-view artwork stays upright; orientation is handled per library.
local root=assert(app.params.root)
local path=root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite'
local s=app.open(path)
local swim,rest
for _,t in ipairs(s.tags) do if t.name=='swim' then swim=t elseif t.name=='swim_idle' then rest=t end end
assert(swim and rest and swim.toFrame.frameNumber-swim.fromFrame.frameNumber==3)
local first=swim.fromFrame.frameNumber;local saved={}
for _,l in ipairs(s.layers) do
 saved[l.name]={}
 for i=0,3 do local c=l:cel(first+i);saved[l.name][i+1]={image=Image(c.image),pos=c.position} end
end
local order={2,3,4,1};local durations={4/60,4/60,4/60,12/60}
for i,source in ipairs(order) do
 for _,l in ipairs(s.layers) do local c=saved[l.name][source];s:newCel(l,first+i-1,c.image,c.pos) end
 s.frames[first+i-1].duration=durations[i]
end
-- No-input swimming in the actual game holds pose 22, not carrying pose 28.
for n=rest.fromFrame.frameNumber,rest.toFrame.frameNumber do
 for _,l in ipairs(s.layers) do local c=saved[l.name][1];s:newCel(l,n,c.image,c.pos) end
 s.frames[n].duration=.4
end
s:saveAs(path)
print('Swim corrected: pull 4 ticks, kick 8, glide 12; rest holds glide')
