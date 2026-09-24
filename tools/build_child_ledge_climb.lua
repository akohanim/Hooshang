-- An upright land catch: retain the child's approved reaching/kneeling art,
-- outlines and sock marks, instead of starting with the prone swimming pose.
local root=app.params.root or '/Users/ari/Hooshang_claude'
local s=app.open(root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite')
local ranges={}; local first=#s.frames+1; local existing
for _,t in ipairs(s.tags) do
 if t.name=='ledge_climb' then existing=t;first=t.fromFrame.frameNumber
 else table.insert(ranges,{tag=t,a=t.fromFrame.frameNumber,b=t.toFrame.frameNumber}) end
end
local sources={40,42,44,64,65,1}
app.transaction('Upright ledge catch, knee tuck and plant',function()
 for i,src in ipairs(sources) do
  local n=first+i-1
  while #s.frames<n do s:newEmptyFrame() end
  for _,layer in ipairs(s.layers) do
   local source=assert(layer:cel(src),'Missing source cel: '..layer.name)
   local old=layer:cel(n);if old then s:deleteCel(old) end
   s:newCel(layer,n,Image(source.image),source.position)
  end
  s.frames[n].duration=.04
 end
 for _,r in ipairs(ranges) do r.tag.fromFrame=r.a;r.tag.toFrame=r.b end
 if not existing then existing=s:newTag(first,first+5);existing.name='ledge_climb' end
 existing.aniDir=AniDir.FORWARD
end)
s:saveAs(s.filename)
print('Child ledge_climb: six upright poses, 240ms, original tags preserved')
