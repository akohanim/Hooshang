shader_type canvas_item;
// Act III water (scenes/props/sea/sea_room.gd): one rect over the whole room,
// masked per 8px cell by `mask` (red = water), drawn ABOVE the player so he is
// in it. What it does to whatever is behind:
//   - a tint toward the depth ramp's sky colour (thin: the room stays readable)
//   - near a SURFACE (a water cell with air above), a refraction wobble — the
//     screen sampled NEAREST, so a fractional offset snaps a whole pixel
//     (assets/shaders/water_distortion.gdshader's rule) — and a bright
//     animated waterline with a dimmer line under it
//   - deep down, no wobble at all: precision platforming under water has to
//     be able to trust where a wall is.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D mask : filter_nearest, repeat_disable;
uniform sampler2D ramp_sky : filter_linear, repeat_disable;
uniform sampler2D ramp_glint : filter_linear, repeat_disable;
uniform sampler2D ramp_chroma : filter_linear, repeat_disable;
uniform float depth_top = 0.0;
uniform float depth_bottom = 2304.0;
uniform float fixed_depth = -1.0;
// Room origin in world px and size in cells; the mask is one texel per cell.
uniform vec2 origin = vec2(0.0);
uniform vec2 cells = vec2(40.0, 24.0);
uniform float tint = 0.27;
uniform float wobble = 1.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float water_at(vec2 cell) {
	// Off the room's edge counts as water: a room's border is solid except at
	// an aperture, and water reaching an aperture carries on into the room
	// beyond — so no false waterline is ever drawn along a seam.
	if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= cells.x || cell.y >= cells.y) {
		return 1.0;
	}
	return texture(mask, (cell + 0.5) / cells).r;
}

// Is this cell open AIR (not water, not rock)? Only air on top of water makes
// a waterline; the underside of a ceiling is not one.
bool air_at(vec2 cell) {
	if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= cells.x || cell.y >= cells.y) {
		return false;
	}
	vec4 m = texture(mask, (cell + 0.5) / cells);
	return m.r < 0.5 && m.g < 0.5;
}

void fragment() {
	vec2 px = floor(world);
	vec2 local = px - origin;
	vec2 cell = floor(local / 8.0);
	if (water_at(cell) < 0.5) {
		discard;
	}
	// Distance below this column's waterline, in px (only the cell above is
	// checked twice; deeper is "deep" and gets no surface treatment).
	float into = mod(local.y, 8.0);
	float depth_px = 99.0;
	if (air_at(cell - vec2(0.0, 1.0))) {
		depth_px = into;
	} else if (water_at(cell - vec2(0.0, 1.0)) > 0.5 && air_at(cell - vec2(0.0, 2.0))) {
		depth_px = into + 8.0;
	}
	float d = fixed_depth >= 0.0 ? fixed_depth
		: clamp((px.y - depth_top) / (depth_bottom - depth_top), 0.0, 1.0);
	vec3 sky = texture(ramp_sky, vec2(d, 0.5)).rgb;
	vec3 glint = texture(ramp_glint, vec2(d, 0.5)).rgb;
	float chroma = texture(ramp_chroma, vec2(d, 0.5)).r;

	// The waterline itself moves: a 1px swell per column.
	float swell = floor(sin(px.x * 0.21 + TIME * 2.3) * 0.7 + sin(px.x * 0.07 - TIME * 1.1) * 0.6 + 0.5);
	float line_y = depth_px - swell;
	if (depth_px < 16.0 && line_y < 0.0) {
		discard;  // above the swell: this pixel is air this frame
	}
	vec2 offset = vec2(0.0);
	float near = 1.0 - smoothstep(4.0, 16.0, depth_px);
	if (near > 0.0) {
		offset.x = sin(px.y * 0.9 + TIME * 3.1) * 1.4 * near * wobble;
	}
	vec3 behind = texture(screen_texture, SCREEN_UV + offset * SCREEN_PIXEL_SIZE).rgb;
	// On the shore (no chroma yet) water is the September look: black, with
	// short white dashes drifting along it — the sea of lines, up close.
	float mono = 1.0 - chroma;
	// A little brighter and cooler than the open water behind it, so air and
	// water in one cave read apart at a glance, not only by the waterline.
	vec3 water = mix(sky * 1.3 + vec3(0.02, 0.05, 0.06), vec3(0.0), mono);
	// Half-way to black, not more: this is drawn over him, and he still has to
	// read when he is under it.
	vec3 col = mix(behind, water, mix(tint * (0.6 + 0.4 * chroma), 0.5, mono));
	if (mono > 0.5 && mod(local.y, 4.0) < 1.0 && depth_px > 2.0) {
		float row = floor(local.y / 4.0);
		float shift = TIME * (5.0 + mod(row * 7.0, 5.0)) * (mod(row, 2.0) < 1.0 ? 1.0 : -1.0);
		float seg = floor((px.x + shift + row * 13.0) / 7.0);
		float on = step(0.7, fract(sin(dot(vec2(seg, row), vec2(127.1, 311.7))) * 43758.5453));
		col = mix(col, vec3(1.0), on * 0.55 * mono);
	}
	if (line_y < 1.0) {
		col = mix(col, glint, 0.85);
	} else if (line_y >= 2.0 && line_y < 3.0 && mod(px.x + floor(TIME * 6.0), 5.0) < 3.0) {
		col = mix(col, glint, 0.35);
	}
	COLOR = vec4(col, 1.0);
}
