-- Audit the editable outline, then use child_outline_render_test for the
-- actual 0.375-scale raster. Source-only 1px checks missed disappearing ink.
local root=assert(app.params.root)
local s=app.open(root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite')
local pc=app.pixelColor
local ink=pc.rgba(0,0,0,255)
local outline
for _,l in ipairs(s.layers) do if l.name:find('Black outline') then outline=l end end
assert(outline,'Missing editable outline layer')
for n=1,#s.frames do
 local cel=assert(outline:cel(n),'Missing outline on frame '..n)
 local count=0
 for it in cel.image:pixels() do
  local c=it()
  if pc.rgbaA(c)>0 then assert(c==ink,'Outline must be opaque black');count=count+1 end
 end
 assert(count>0,'Empty outline on frame '..n)
end
print('Audited black outline cels on all '..#s.frames..' frames / '..#s.tags..' tags')
