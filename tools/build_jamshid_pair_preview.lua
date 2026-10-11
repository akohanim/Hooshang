-- Validate against child Hooshang and author an animated side-by-side review.
local root=(app.params.root or '/Users/ari/Hooshang_claude')..'/'
local h=app.open(root..'assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite')
local j=app.open(root..'assets/characters/jamshid/aseprite/jamshid_child_movement.aseprite')
assert(#j.layers==#h.layers and #j.frames==#h.frames and #j.tags==#h.tags)
local p=Sprite(176,88,ColorMode.RGB)
for f=1,#h.frames do
 if f>1 then p:newEmptyFrame() end
 assert(h.frames[f].duration==j.frames[f].duration)
 local im=Image(176,88,ColorMode.RGB); im:clear(app.pixelColor.rgba(48,59,64,255))
 local a=Image(88,88,ColorMode.RGB); a:drawSprite(h,f)
 local b=Image(88,88,ColorMode.RGB); b:drawSprite(j,f)
 for y=0,87 do for x=0,87 do assert(app.pixelColor.rgbaA(a:getPixel(x,y))==app.pixelColor.rgbaA(b:getPixel(x,y)), 'Silhouette mismatch '..f) end end
 im:drawImage(a,Point(0,0)); im:drawImage(b,Point(88,0))
 p:newCel(p.layers[1],f,im,Point(0,0)); p.frames[f].duration=h.frames[f].duration
end
for i,t in ipairs(h.tags) do local u=j.tags[i]; assert(t.name==u.name and t.fromFrame.frameNumber==u.fromFrame.frameNumber and t.toFrame.frameNumber==u.toFrame.frameNumber and t.aniDir==u.aniDir); local tag=p:newTag(t.fromFrame.frameNumber,t.toFrame.frameNumber); tag.name=t.name; tag.aniDir=t.aniDir end
p:saveAs(root..'output/jamshid_pair/pair.aseprite')
print('PASS: 63 source frames, 24 tag ranges/directions, all durations and silhouettes, five editable layers match child Hooshang')
