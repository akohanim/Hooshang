-- Tuck the adult crouch's ankles under the head, preserving every other frame.
-- Run with Aseprite --batch --script-param source=<file> --script <this file>.
local s = app.open(assert(app.params.source, 'Pass the source Aseprite file'))
local tag
for _, candidate in ipairs(s.tags) do if candidate.name == 'crouch' then tag = candidate end end
assert(tag and tag.fromFrame == tag.toFrame, 'Expected the single authored crouch frame')
local frame = tag.fromFrame.frameNumber
local layer = s.layers[1]
assert(layer.name == 'Hooshang', 'Unexpected artwork layer')
local cel = assert(layer:cel(frame))
local image = Image(cel.image)
local pc = app.pixelColor
local clear = pc.rgba(0, 0, 0, 0)
local outline = pc.rgba(0, 0, 0, 255)
local trousers = pc.rgba(102, 21, 49, 255)
local socks = pc.rgba(255, 255, 255, 255)
local function pixel(x, y, color)
 image:putPixel(x - cel.position.x, y - cel.position.y, color)
end
app.transaction('Tuck crouch socks into a squat', function()
 for y = 15, 17 do for x = 0, 17 do pixel(x, y, clear) end end
 -- Bent knees taper into two planted feet, rather than a wide seated base.
 for x = 4, 14 do pixel(x, 15, outline) end
 for _, x in ipairs({5, 6, 7, 10, 11, 12}) do pixel(x, 15, trousers) end
 for x = 5, 12 do pixel(x, 16, outline) end
 for _, x in ipairs({6, 7, 10, 11}) do pixel(x, 16, socks) end
 for _, x in ipairs({5, 6, 7, 10, 11, 12}) do pixel(x, 17, outline) end
 cel.image = image
end)
s:saveAs(s.filename)
print('Saved crouch frame '..frame..': sock pairs at x=6..7 and x=10..11, feet remain on row 17')
