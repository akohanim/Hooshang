-- Fill the former cap-brim gap with hair in the current editable artwork.
local root=assert(app.params.root)
local path=root..'/assets/characters/hooshang_child/aseprite/young_hooshang_movement.aseprite'
local s=app.open(path)
local f=assert(io.open(root..'/output/child_small_mario/reference_poses.json'))
local refs=json.decode(f:read('*a'));f:close()
local pc=app.pixelColor
local layers={};for _,l in ipairs(s.layers) do layers[l.name]=l end
local function blank() return Image(88,88,ColorMode.RGB) end
local function canvas(l,n) local im=blank();local c=l:cel(n);im:drawImage(c.image,c.position);return im end
local mappings={idle={0},run={0,1},jump={11},fall={36},dash={4,5},wall_slide={13},wall_jump={11},climb={21,21},swim={22,26,26,24},swim_idle={28,28},exit_water={11,11,14,14,1,0},sit={60,60},ledge_climb={11,11,14,14,1,0}}
local filled=0
for _,t in ipairs(s.tags) do
 for n=t.fromFrame.frameNumber,t.toFrame.frameNumber do
  if t.name~='climb' then
   local i=n-t.fromFrame.frameNumber+1;local pose=mappings[t.name][i]
   local top=15;if pose==36 then top=13 elseif pose==13 then top=14 elseif pose==60 then top=23 end
   local shift=((t.name=='run' or t.name=='sit') and i==2) and -2 or 0
   local face=canvas(layers['Face hair and hands'],n)
   local details=canvas(layers['Interior black details'],n)
   for row=top,top+1 do for x,id in ipairs(refs[pose+1].pixels[row+1]) do
    if id==2 then
     for yy=row*2+shift,row*2+shift+1 do for xx=28+(x-1)*2,29+(x-1)*2 do
      face:putPixel(xx,yy,pc.rgba(43,42,56,255));details:putPixel(xx,yy,0);filled=filled+1
     end end
    end
   end end
   s:newCel(layers['Face hair and hands'],n,face,Point(0,0))
   s:newCel(layers['Interior black details'],n,details,Point(0,0))
   local body=blank();body:drawImage(canvas(layers['Clothing and shoes'],n));body:drawImage(face);body:drawImage(details)
   local ring=blank()
   for y=1,86 do for x=1,86 do
    if pc.rgbaA(body:getPixel(x,y))==0 then
     local adjacent=false
     for dy=-1,1 do for dx=-1,1 do if pc.rgbaA(body:getPixel(x+dx,y+dy))>0 then adjacent=true end end end
     if adjacent then ring:putPixel(x,y,pc.rgba(0,0,0,255)) end
    end
   end end
   s:newCel(layers['Black outline - 1px'],n,ring,Point(0,0))
  end
 end
end
s:saveAs(path)
print('Filled '..filled..' source pixels with hair; preserved eyes, skin and animation timing')
