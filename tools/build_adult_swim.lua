-- Adult Hooshang's swim, redrawn to match the child's Super Mario World stroke
-- (assets/characters/hooshang_child/aseprite/README.md): side view, head upright,
-- reach -> pull -> kick -> long glide with one arm forward and the legs trailing.
-- The old clips were a front-facing arm windmill and a standing T-pose, rotated
-- 90 degrees in game; these are drawn side-on and are not rotated (player.gd).
--
-- A one-time authoring recipe, like tools/build_child_small_mario.lua: it
-- overwrites the swim/swim_idle cels in hooshang_18px_movement.aseprite. Do not
-- run it over later hand edits. Then: python3 tools/import_hooshang_aseprite.py
--
--   aseprite -b assets/characters/hooshang/aseprite/hooshang_18px_movement.aseprite \
--     --script tools/build_adult_swim.lua
--
-- Timing keeps the child's 4 / 8 / 12 tick ratio (66 ms per frame): reach, two
-- pull frames, three glide frames. The idle float holds the glide and lets the
-- legs and the forward hand drift on a slow 880 ms cycle.

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
}

local POSES = {
  REACH = {
    "..................",
    "........aaaaa.....",
    ".......abbbbba....",
    "......abbcccda....",
    "......adccccca....",
    "......aaccdcca....",
    ".......acbbbca....",
    "......aeccccca....",
    ".....aaafgffgea...",
    ".....aeafgggehaa..",
    ".....aeaggggheeaa.",
    "....aaaagggghhaeca",
    "...aiiihhhhhhaacda",
    "..aiiiiijjaa..aaa.",
    ".aiiaaaiijja......",
    ".akka..aakka......",
    ".aaa...aaaaa......",
    "..................",
  },
  PULL = {
    "..................",
    "........aaaaa.....",
    ".......abbbbba....",
    "......abbcccda....",
    "......adccccca....",
    "......aaccdcca....",
    ".......acbbbca....",
    "......aeccccca....",
    ".....aaafgffgea...",
    "....aeeafggggha...",
    "...aceeaggggheha..",
    "..acca.aaggghhea..",
    "..aaa.aiihhhhaa...",
    ".aaaaiiiiijaa.....",
    "akkiiiiijjaa......",
    "akkaaaaaaa........",
    "aaa...............",
    "..................",
  },
  KICK = {
    "..................",
    "........aaaaa.....",
    ".......abbbbba....",
    "......abbcccda....",
    "......adccccca....",
    "......aaccdcca....",
    ".......acbbbca....",
    "......aeccccca....",
    ".....aaafgffgea...",
    "....aeeafggggha...",
    "...aceeaggggheha..",
    "..acca.aaggghhea..",
    ".aaaaaaiihhhhaa...",
    "akkiiiiiiijaa.....",
    "akkaaaaaaaaa......",
    "aaa...............",
    "..................",
    "..................",
  },
  GLIDE = {
    "..................",
    "........aaaaa.....",
    ".......abbbbba....",
    "......abbcccda....",
    "......adccccca....",
    "......aaccdcca....",
    ".......acbbbca....",
    "......aecccccaaaa.",
    ".....aaafgffgeeeca",
    ".....aeafgggehaada",
    ".....aaeagggghhaa.",
    "....aaeeeggghhha..",
    "..aaiiihhhhhhaa...",
    ".aiiiiiiijjaa.....",
    "akkaaaaaaaaa......",
    "aaa...............",
    "..................",
    "..................",
  },
  GLIDE_SINK = {
    "..................",
    "........aaaaa.....",
    ".......abbbbba....",
    "......abbcccda....",
    "......adccccca....",
    "......aaccdcca....",
    ".......acbbbca....",
    "......aecccccaaaa.",
    ".....aaafgffgeeeca",
    ".....aeafgggehaada",
    ".....aaeagggghhaa.",
    "....aaeeeggghhha..",
    "............haa...",
    "..aaiiihhhhha.....",
    ".aiiiiiiijja......",
    "akkaaaaaaaaa......",
    "aaa...............",
    "..................",
  },
  GLIDE_LOW_SINK = {
    "..................",
    "........aaaaa.....",
    ".......abbbbba....",
    "......abbcccda....",
    "......adccccca....",
    "......aaccdcca....",
    ".......acbbbca....",
    "......aecccccaaa..",
    ".....aaafgffgeeeda",
    ".....aeafgggehaaca",
    ".....aaeagggghaada",
    "....aaeeeggghhhaa.",
    "............haa...",
    "..aaiiihhhhha.....",
    ".aiiiiiiijja......",
    "akkaaaaaaaaa......",
    "aaa...............",
    "..................",
  },
}

-- Aseprite frame numbers (1-based) and ms. swim is tag 60-65, swim_idle 66-69;
-- the counts are unchanged so no later frame moves.
local FRAMES = {
  { 60, "REACH", 66 },
  { 61, "PULL", 66 },
  { 62, "KICK", 66 },
  { 63, "GLIDE", 66 },
  { 64, "GLIDE", 66 },
  { 65, "GLIDE_SINK", 66 },
  { 66, "GLIDE", 220 },
  { 67, "GLIDE_SINK", 220 },
  { 68, "GLIDE_LOW_SINK", 220 },
  { 69, "GLIDE_SINK", 220 },
}

local spr = app.activeSprite
assert(spr and spr.width == 18 and spr.height == 18 and spr.colorMode == ColorMode.RGB,
  "open hooshang_18px_movement.aseprite (18x18 RGB)")
local function tag(name)
  for _, t in ipairs(spr.tags) do if t.name == name then return t end end
end
assert(tag("swim").fromFrame.frameNumber == 60 and tag("swim").toFrame.frameNumber == 65, "swim tag moved")
assert(tag("swim_idle").fromFrame.frameNumber == 66 and tag("swim_idle").toFrame.frameNumber == 69, "swim_idle tag moved")

local layer = spr.layers[1]
local function colour(hex)
  return app.pixelColor.rgba(tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16), 255)
end

app.transaction("Adult swim (SMW stroke)", function()
  for _, f in ipairs(FRAMES) do
    local number, pose, ms = f[1], POSES[f[2]], f[3]
    local img = Image(18, 18, ColorMode.RGB)
    img:clear(0)
    for y = 1, 18 do
      local row = pose[y]
      assert(#row == 18, f[2] .. " row " .. y)
      for x = 1, 18 do
        local key = row:sub(x, x)
        if key ~= "." then
          assert(PAL[key], f[2] .. " unknown colour " .. key)
          img:drawPixel(x - 1, y - 1, colour(PAL[key]))
        end
      end
    end
    local cel = layer:cel(number)
    if cel then
      cel.image = img
      cel.position = Point(0, 0)
    else
      spr:newCel(layer, number, img, Point(0, 0))
    end
    spr.frames[number].duration = ms / 1000
  end
end)
spr:saveAs(spr.filename)
print("adult swim: wrote frames 60-69")

