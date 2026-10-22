-- One-time authoring recipe for the approved ImageGen finale cast.
-- Run with Aseprite --batch --script tools/build_finale_cast.lua from repo root.
-- This replaces the cast sources: ordinary hand edits should only be exported.
local ROOT = app.params["root"] or "."
local function path(p) return ROOT .. "/" .. p end
local pc = app.pixelColor
local function rgba(hex)
  return pc.rgba(tonumber(hex:sub(2,3),16),tonumber(hex:sub(4,5),16),tonumber(hex:sub(6,7),16),255)
end
local tiger_palette = {
  "#24160f", "#38231a", "#573322", "#87502c", "#aa5b24", "#cd732a",
  "#e58b35", "#f5a74b", "#ffc46c", "#a69377", "#d6c19b", "#f3dfb8",
  "#fff0ce", "#7e2732", "#bd5960", "#e9b541", "#fff8e8",
}
local mouse_palette = {
  "#201a20", "#302b39", "#444052", "#68637d", "#928c9c", "#aaa396",
  "#c8c0ae", "#e5deca", "#fff0d6", "#b76c78", "#e798a3", "#ffc0c0",
}
local function palette(hexes)
  local out={}
  for _,h in ipairs(hexes) do out[#out+1]=rgba(h) end
  return out
end
local function nearest(p,colors)
  local best,dist=colors[1],math.huge
  for _,q in ipairs(colors) do
    local d=(pc.rgbaR(p)-pc.rgbaR(q))^2+(pc.rgbaG(p)-pc.rgbaG(q))^2+(pc.rgbaB(p)-pc.rgbaB(q))^2
    if d<dist then best,dist=q,d end
  end
  return best
end
local function opaque(p) return pc.rgbaA(p)>=160 end
local function blank(w,h) local im=Image(w,h,ColorMode.RGB) im:clear(0) return im end
-- Isolate each approved pose, preserve aspect ratio, and snap to opaque native
-- pixels. Only the largest connected silhouette is kept (no alpha fringe dust).
local function extract(sheet,index,w,h,colors)
  local col,row=index%3,math.floor(index/3)
  local x0,y0=math.floor(sheet.width*col/3),math.floor(sheet.height*row/2)
  local x1,y1=math.floor(sheet.width*(col+1)/3)-1,math.floor(sheet.height*(row+1)/2)-1
  local left,top,right,bottom=x1,y1,x0,y0
  for y=y0,y1 do for x=x0,x1 do
    if opaque(sheet:getPixel(x,y)) then left=math.min(left,x) top=math.min(top,y) right=math.max(right,x) bottom=math.max(bottom,y) end
  end end
  local factor=math.min((w-2)/(right-left+1),(h-1)/(bottom-top+1))
  local dw,dh=math.floor((right-left+1)*factor+0.5),math.floor((bottom-top+1)*factor+0.5)
  local out=blank(w,h)
  local ox,oy=math.floor((w-dw)/2),h-dh
  for y=0,dh-1 do for x=0,dw-1 do
    local p=sheet:getPixel(left+math.floor((x+0.5)*(right-left+1)/dw),top+math.floor((y+0.5)*(bottom-top+1)/dh))
    if opaque(p) then out:drawPixel(ox+x,oy+y,nearest(p,colors)) end
  end end
  local seen,largest={},{}
  for y=0,h-1 do for x=0,w-1 do
    local key=y*w+x
    if not seen[key] and opaque(out:getPixel(x,y)) then
      local queue={{x,y}} seen[key]=true local at=1
      while at<=#queue do
        local p=queue[at] at=at+1
        for dy=-1,1 do for dx=-1,1 do
          local nx,ny=p[1]+dx,p[2]+dy local nk=ny*w+nx
          if nx>=0 and nx<w and ny>=0 and ny<h and not seen[nk] and opaque(out:getPixel(nx,ny)) then
            seen[nk]=true queue[#queue+1]={nx,ny}
          end
        end end
      end
      if #queue>#largest then largest=queue end
    end
  end end
  local clean=blank(w,h)
  for _,p in ipairs(largest) do clean:drawPixel(p[1],p[2],out:getPixel(p[1],p[2])) end
  return clean
end
local tiger_sheet=Image{fromFile=path("assets/characters/tiger/source/approved_finale/concept.png")}
local mice_sheet=Image{fromFile=path("assets/characters/mice/source/concept.png")}
for n=0,5 do
  extract(tiger_sheet,n,44,22,palette(tiger_palette)):saveAs(path("assets/characters/tiger/source/approved_finale/pose_"..n..".png"))
  extract(mice_sheet,n,14,8,palette(mouse_palette)):saveAs(path("assets/characters/mice/source/pose_"..n..".png"))
end
print("Extracted six native tiger and six native mouse key poses")

local function round(n) return math.floor(n+0.5) end
local function copy_where(src,predicate,dx,dy)
  local im=blank(src.width,src.height)
  for y=0,src.height-1 do for x=0,src.width-1 do
    if predicate(x,y) then
      local xx,yy=x+(dx or 0),y+(dy or 0)
      if xx>=0 and xx<im.width and yy>=0 and yy<im.height then im:drawPixel(xx,yy,src:getPixel(x,y)) end
    end
  end end
  return im
end
local function line(im,ax,ay,bx,by,width,color)
  for y=0,im.height-1 do for x=0,im.width-1 do
    local vx,vy=bx-ax,by-ay
    local t=math.max(0,math.min(1,((x-ax)*vx+(y-ay)*vy)/math.max(0.001,vx*vx+vy*vy)))
    if (x-ax-t*vx)^2+(y-ay-t*vy)^2<=(width/2)^2 then im:drawPixel(x,y,color) end
  end end
end
local function leg(im,hx,hy,fx,fy,far,rear)
  local mask=blank(44,22)
  local flex=1+math.max(0,20-fy)*0.35
  local knee_x=(hx+fx)/2+(rear and -flex or flex)
  local knee_y=(hy+fy)/2
  line(mask,hx,hy,knee_x,knee_y,far and 1.5 or 2.5,rgba("#e58b35"))
  line(mask,knee_x,knee_y,fx,fy-0.5,far and 1.5 or 2,rgba("#e58b35"))
  line(mask,fx-0.5,fy,fx+1,fy,2,rgba("#f3dfb8"))
  -- Outline each connected limb, including the knee, before laying its fill.
  for y=0,21 do for x=0,43 do
    if not opaque(mask:getPixel(x,y)) then
      for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        local nx,ny=x+d[1],y+d[2]
        if nx>=0 and nx<44 and ny>=0 and ny<22 and opaque(mask:getPixel(nx,ny)) then im:drawPixel(x,y,rgba("#24160f")) break end
      end
    end
  end end
  for y=0,21 do for x=0,43 do
    if opaque(mask:getPixel(x,y)) then
      local c
      if y>=fy-1 then c=rgba(far and "#a69377" or "#f3dfb8")
      elseif y==round(knee_y) then c=rgba(far and "#573322" or "#38231a")
      else c=rgba(far and "#aa5b24" or "#e58b35") end
      im:drawPixel(x,y,c)
    end
  end end
end
local tiger_base={}
for n=0,5 do tiger_base[n]=Image{fromFile=path("assets/characters/tiger/source/approved_finale/pose_"..n..".png")} end
local function gait(n,running)
  local im=blank(44,22)
  local cycle=n/12
  local theta=cycle*math.pi*2
  local bob=running and -round(1+0.8*math.sin(theta-0.3)) or 0
  local feet={}
  for i,hip in ipairs({17,26,12,32}) do
    -- During stance the paw sweeps back at almost ground speed. During
    -- recovery it follows a smooth raised arc, with staggered pairs rather
    -- than four legs snapping between independent hand-picked positions.
    local offsets=running and {0.58,0.10,0.46,0} or {0.5,0.75,0,0.25}
    local phase=(cycle+offsets[i])%1
    local stance=running and 0.34 or 0.62
    local stride=running and 6 or 6.5
    local dx,fy
    if phase<stance then
      dx=stride*(1-2*phase/stance)
      fy=20
    else
      local swing=(phase-stance)/(1-stance)
      dx=-stride+2*stride*swing
      fy=20-(running and 5 or 3)*math.sin(swing*math.pi)
    end
    feet[i]={hip+dx,fy}
  end
  leg(im,17,14+bob,feet[1][1],feet[1][2],true,true)
  leg(im,26,14+bob,feet[2][1],feet[2][2],true,false)
  -- Approved back, stripes, head, muzzle and tail survive intact. New jointed
  -- limbs provide the in-betweens; a moving whole-image cutout cannot walk.
  local body=copy_where(tiger_base[0],function(x,y) return y<=14 and x>10 end,0,bob)
  local tail=copy_where(tiger_base[0],function(x,y) return y<=14 and x<=10 end,0,bob+round(math.sin(theta)*0.7))
  im:drawImage(tail)
  im:drawImage(body)
  leg(im,12,14+bob,feet[3][1],feet[3][2],false,true)
  leg(im,32,14+bob,feet[4][1],feet[4][2],false,false)
  return im
end
local function acting(base,n,kind)
  local src=tiger_base[base]
  local tail_end=base==4 and 12 or 10
  local tail_bottom=base==5 and 18 or 16
  local dy=({0,-1,0,1})[n%4+1]
  local im=copy_where(src,function(x,y) return not (x<=tail_end and y<tail_bottom) end)
  im:drawImage(copy_where(src,function(x,y) return x<=tail_end and y<tail_bottom end,0,dy))
  if kind=="roar" then
    -- A four-pixel jaw window hinges below the cream cheek, with a dark mouth
    -- behind it. The forepaws remain planted throughout the six-frame roar.
    local jaw=copy_where(src,function(x,y) return x>=38 and y>=8 and y<=10 end)
    for y=8,11 do for x=38,41 do
      if opaque(src:getPixel(x,y)) then im:drawPixel(x,y,rgba("#7e2732")) end
    end end
    im:drawImage(copy_where(jaw,function() return true end,0,({0,1,1,0,-1,0})[n+1]))
  elseif n==2 then
    -- One rest frame carries a deliberate blink, outside the gait cycles.
    local ex,ey=base==4 and 36 or 39,base==4 and 4 or 10
    if opaque(im:getPixel(ex,ey)) then im:drawPixel(ex,ey,rgba("#573322")) end
  end
  return im
end
local function build_source(w,h,name,clips,out,frames_dir)
  local spr=Sprite(w,h,ColorMode.RGB)
  local layer=spr.layers[1] layer.name=name
  local at=1 local tags={}
  for _,clip in ipairs(clips) do
    local start=at
    for n,img in ipairs(clip.images) do
      if at>1 then spr:newEmptyFrame() end
      spr:newCel(layer,at,img,Point(0,0))
      spr.frames[at].duration=(type(clip.ms)=="table" and clip.ms[n] or clip.ms)/1000
      img:saveAs(path(frames_dir.."/"..clip.name.."_"..(n-1)..".png"))
      at=at+1
    end
    tags[#tags+1]={start,at-1,clip.name}
  end
  -- Adding a frame at a tag's endpoint extends that tag in Aseprite. Define
  -- the complete timeline first so adjacent clips cannot bleed into each other.
  for _,t in ipairs(tags) do local tag=spr:newTag(t[1],t[2]) tag.name=t[3] end
  spr:saveAs(path(out))
  print(name..": "..(at-1).." editable frames in "..#clips.." clips")
end
local tiger_clips={}
local previous=nil
if app.params["refine"] then previous=app.open(path("assets/characters/tiger/tiger.aseprite")) end
for _,name in ipairs({"walk","run","idle","roar","look_down","look_up","crouch"}) do
  local images={} local count=(name=="walk" or name=="run") and 12 or (name=="roar" and 6 or 4)
  local saved_tag=nil
  if previous and name~="walk" and name~="run" then
    for _,t in ipairs(previous.tags) do if t.name==name then saved_tag=t end end
  end
  local ms=({walk=73,run=43,idle=240,roar=130,look_down=300,look_up=300,crouch=180})[name]
  if saved_tag then
    ms={}
    for f=saved_tag.fromFrame.frameNumber,saved_tag.toFrame.frameNumber do
      local img=blank(44,22) img:drawSprite(previous,f)
      images[#images+1]=img ms[#ms+1]=round(previous.frames[f].duration*1000)
    end
  else
  for n=0,count-1 do
    if name=="walk" or name=="run" then images[#images+1]=gait(n,name=="run")
    else images[#images+1]=acting(({idle=0,roar=2,look_down=3,look_up=4,crouch=5})[name],n,name) end
  end
  end
  tiger_clips[#tiger_clips+1]={name=name,images=images,ms=ms}
end
build_source(44,22,"Tiger",tiger_clips,"assets/characters/tiger/tiger.aseprite","assets/characters/tiger/frames")

if app.params["tiger-only"] then return end
local mouse_clips={}
for row=0,1 do
  local base={}
  for col=0,2 do base[col]=Image{fromFile=path("assets/characters/mice/source/pose_"..(row*3+col)..".png")} end
  local prefix=row==0 and "black_" or "white_"
  local walk={}
  for n=0,3 do
    local src=base[0]
    local im=copy_where(src,function(x,y) return x>=5 and y<7 end)
    im:drawImage(copy_where(src,function(x,y) return x<5 end,0,({0,-1,0,1})[n+1]))
    -- Two pairs of pink paws alternate independently of the anchored torso.
    for i,x in ipairs({5,9}) do
      local offset=(i==1 and {0,1,1,0} or {1,0,-1,0})[n+1]
      im:drawPixel(x+offset,7,rgba(row==0 and "#b76c78" or "#e798a3"))
    end
    walk[#walk+1]=im
  end
  -- The approved three jaw/ear poses are the extremes of a six-beat gnaw.
  -- Repeated rests slow the chewing; an incisor flashes only on the bite.
  local gnaw={Image(base[0]),Image(base[1]),Image(base[1]),Image(base[2]),Image(base[1]),Image(base[0])}
  mouse_clips[#mouse_clips+1]={name=prefix.."walk",images=walk,ms=90}
  mouse_clips[#mouse_clips+1]={name=prefix.."gnaw",images=gnaw,ms={160,100,100,120,100,180}}
end
build_source(14,8,"Mice",mouse_clips,"assets/characters/mice/mice.aseprite","assets/characters/mice/frames")
