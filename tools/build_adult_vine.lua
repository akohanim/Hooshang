-- Adult Hooshang on the vine, Act III's last scene (SCRIPT.md THIRTEEN): hanging
-- with both hands round it, looking down at the tiger below and up at the one
-- above, reaching for the lemon, eating it, and the eyes-closed end.
--
-- A one-time authoring recipe like tools/build_adult_swim.lua. It APPENDS these
-- clips after the existing frames (so no frame any other clip uses moves), or
-- overwrites them in place if their tags are already there. Then:
--   python3 tools/import_hooshang_aseprite.py
--
--   aseprite -b assets/characters/hooshang/aseprite/hooshang_18px_movement.aseprite \
--     --script tools/build_adult_vine.lua

local PAL = {
  a = "#000000",
  b = "#2d282f",
  c = "#ffa563",
  d = "#de884c",
  e = "#70371c",
  f = "#5bb0da",
  g = "#91d8f5",
  h = "#4d2511",
  i = "#661531",
  j = "#440f21",
  k = "#ffffff",
  y = "#f6d43c",
  Y = "#fff08a",
  o = "#d0a52a",
}

local POSES = {
  HANG = {
    ".......aaaa.......",
    "......acddca......",
    ".....aeaccaea.....",
    "....aea.aa.aea....",
    "....aeaaaaaaea....",
    "....aeabbbbbea....",
    "....aeabcccdea....",
    "....aeadcccca.....",
    "....aeaaccdcca....",
    "....aea.acbbba....",
    ".....aeaecccca....",
    ".....aaafgffgaa...",
    "......aefgggea....",
    "......aefgggha....",
    "......aahhhhaa....",
    ".......aiaaia.....",
    ".......akaaka.....",
    ".......aaa.aa.....",
  },
  LOOK_DOWN = {
    ".......aaaa.......",
    "......acddca......",
    ".....aeaccaea.....",
    "....aea.aa.aea....",
    "....aeaaaaaaea....",
    "....aeabbbbbea....",
    "....aeabbbbbda....",
    "....aeabcccca.....",
    "....aeadccdcca....",
    "....aeaaacbbba....",
    ".....aeaeccca.....",
    ".....aaafgffgaa...",
    "......aefgggea....",
    "......aefgggha....",
    "......aahhhhaa....",
    ".......aiaaia.....",
    ".......akaaka.....",
    ".......aaa.aa.....",
  },
  LOOK_UP = {
    ".......aaaa.......",
    "......acddca......",
    ".....aeaccaea.....",
    "....aea.aa.aea....",
    "....aeaaaaaaea....",
    "....aeaccdccea....",
    "....aeacbbbca.....",
    "....aeacccccca....",
    "....aeadcccca.....",
    "....aea.accca.....",
    ".....aeaecccca....",
    ".....aaafgffgaa...",
    "......aefgggea....",
    "......aefgggha....",
    "......aahhhhaa....",
    ".......aiaaia.....",
    ".......akaaka.....",
    ".......aaa.aa.....",
  },
  REACH = {
    ".......aaaa.......",
    "......acddca......",
    ".....aeaccaa......",
    "....aea.aa........",
    "....aeaaaaaa......",
    "....aeabbbbba.....",
    "....aeabcccda.....",
    "....aeadccccca....",
    "....aeaaccdcca....",
    "....aea.acbbba....",
    ".....aeaecccca....",
    ".....aaafgffgeeeaa",
    "......aefgggeeecca",
    "......aefgggha.aa.",
    "......aahhhhaa....",
    ".......aiaaia.....",
    ".......akaaka.....",
    ".......aaa.aa.....",
  },
  EAT = {
    ".......aaaa.......",
    "......acddca......",
    ".....aeaccaa......",
    "....aea.aa........",
    "....aeaaaaaa......",
    "....aeabbbbba.....",
    "....aeabcccda.....",
    "....aeadcccca.....",
    "....aeaaccdcaaa...",
    "....aea.acbbayya..",
    ".....aeaecccaYya..",
    ".....aaafgffcaoa..",
    "......aefgggeca...",
    "......aefgggeea...",
    "......aahhhhaa....",
    ".......aiaaia.....",
    ".......akaaka.....",
    ".......aaa.aa.....",
  },
  CHEW = {
    ".......aaaa.......",
    "......acddca......",
    ".....aeaccaa......",
    "....aea.aa........",
    "....aeaaaaaa......",
    "....aeabbbbba.....",
    "....aeabcccda.....",
    "....aeadcccca.....",
    "....aeaaccdcca....",
    "....aea.acbbca....",
    ".....aeaecccaya...",
    ".....aaafgffcaa...",
    "......aefgggeca...",
    "......aefgggeea...",
    "......aahhhhaa....",
    ".......aiaaia.....",
    ".......akaaka.....",
    ".......aaa.aa.....",
  },
  CONTENT = {
    ".......aaaa.......",
    "......acddca......",
    ".....aeaccaea.....",
    "....aea.aa.aea....",
    "....aeaaaaaaea....",
    "....aeabbbbbea....",
    "....aeabcccdea....",
    "....aeadcccca.....",
    "....aeaccccdca....",
    "....aea.adbbda....",
    ".....aeaecccca....",
    ".....aaafgffgaa...",
    "......aefgggea....",
    "......aefgggha....",
    "......aahhhhaa....",
    ".......aiaaia.....",
    ".......akaaka.....",
    ".......aaa.aa.....",
  },
}

-- tag name, then { pose, ms } per frame
local CLIPS = {
  { "hang", { { "HANG", 400 } } },
  { "hang_look_down", { { "LOOK_DOWN", 400 } } },
  { "hang_look_up", { { "LOOK_UP", 400 } } },
  { "hang_reach", { { "REACH", 400 } } },
  { "hang_eat", { { "EAT", 260 }, { "CHEW", 260 } } },
  { "hang_content", { { "CONTENT", 400 } } },
}

local spr = app.activeSprite
assert(spr and spr.width == 18 and spr.height == 18 and spr.colorMode == ColorMode.RGB,
  "open hooshang_18px_movement.aseprite (18x18 RGB)")
local layer = spr.layers[1]
local function colour(hex)
  return app.pixelColor.rgba(tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16), 255)
end
local function tag(name)
  for _, t in ipairs(spr.tags) do if t.name == name then return t end end
end
local function image(pose)
  local img = Image(18, 18, ColorMode.RGB)
  img:clear(0)
  for y = 1, 18 do
    local row = pose[y]
    assert(#row == 18)
    for x = 1, 18 do
      local key = row:sub(x, x)
      if key ~= "." then img:drawPixel(x - 1, y - 1, colour(assert(PAL[key], key))) end
    end
  end
  return img
end

app.transaction("Adult vine poses", function()
  for _, clip in ipairs(CLIPS) do
    local name, frames = clip[1], clip[2]
    local t = tag(name)
    local first
    if t then
      assert(t.toFrame.frameNumber - t.fromFrame.frameNumber + 1 == #frames, name .. " changed length")
      first = t.fromFrame.frameNumber
    else
      first = #spr.frames + 1
      for i = 1, #frames do spr:newEmptyFrame(#spr.frames + 1) end
    end
    for i, f in ipairs(frames) do
      local number = first + i - 1
      local cel = layer:cel(number)
      if cel then cel.image = image(POSES[f[1]]); cel.position = Point(0, 0)
      else spr:newCel(layer, number, image(POSES[f[1]]), Point(0, 0)) end
      spr.frames[number].duration = f[2] / 1000
    end
    if not t then
      local nt = spr:newTag(first, first + #frames - 1)
      nt.name = name
    end
  end
end)
spr:saveAs(spr.filename)
print("adult vine: " .. #spr.frames .. " frames")

