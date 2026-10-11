-- One-time sibling design from the CURRENT Act 2 child source.
-- Ordinary hand edits are exported with import_jamshid_aseprite.py instead.
local root=app.params.root or '/Users/ari/Hooshang_claude'
local s=app.open(root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite')
local pc=app.pixelColor
local function rgb(r,g,b) return pc.rgba(r,g,b,255) end
local palette={}
local function map(r,g,b,rr,gg,bb) palette[rgb(r,g,b)]=rgb(rr,gg,bb) end
-- Same light/shadow hierarchy, with Jamshid's green/cream/navy outfit.
map(77,37,17,29,57,40); map(112,55,28,52,91,53)
map(91,176,218,200,169,112); map(145,216,245,245,224,167)
map(102,21,49,38,57,82); map(68,15,33,22,33,53)
-- Warm dark hair distinguishes his face without changing the approved child form.
map(22,22,30,25,20,18); map(43,42,56,48,34,26); map(79,77,92,82,57,38)
local before={}
for f=1,#s.frames do local im=Image(88,88); im:drawSprite(s,f); before[f]=im end
-- Clone each cel before changing pixels: linked cels must not be recoloured twice.
for _,l in ipairs(s.layers) do
 for _,c in ipairs(l.cels) do
  local im=Image(c.image)
  for px in im:pixels() do local target=palette[px()]; if target then px(target) end end
  c.image=im
 end
end
for f=1,#s.frames do
 local im=Image(88,88); im:drawSprite(s,f)
 for y=0,87 do for x=0,87 do assert(pc.rgbaA(im:getPixel(x,y))==pc.rgbaA(before[f]:getPixel(x,y)), 'Silhouette changed') end end
end
s:saveAs(root..'/assets/characters/jamshid/aseprite/jamshid_child_movement.aseprite')
print('Saved Jamshid child: '..#s.frames..' frames, '..#s.tags..' tags, '..#s.layers..' editable layers; every silhouette preserved')
