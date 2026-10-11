local root=assert(app.params.root)
local base=root..'/assets/characters/jamshid/'
local s=app.open(base..'aseprite/jamshid_child_movement.aseprite')
local sock
for _,l in ipairs(s.layers) do if l.name=='Socks - 1px marks' then sock=l end end
assert(sock)
local marks={}
for f=1,#s.frames do
 local cel=assert(sock:cel(f)); local points={}
 for y=0,cel.image.height-1 do for x=0,cel.image.width-1 do if app.pixelColor.rgbaA(cel.image:getPixel(x,y))>0 then table.insert(points,{x+cel.position.x,y+cel.position.y}) end end end
 assert(#points==2); marks[f]=points
end
sock.isVisible=false
app.command.ExportSpriteSheet{ui=false,type=SpriteSheetType.HORIZONTAL,textureFilename=base..'sprites/child/movement.png',dataFilename=base..'sprites/child/movement.json',listTags=true,listLayers=true,dataFormat=SpriteSheetDataFormat.JSON_ARRAY}
local file=assert(io.open(base..'sprites/child/socks.json','w')); file:write(json.encode(marks)); file:close()
