shader_type canvas_item;
// A tree (anchored at its roots) or a hanging canopy (anchored along its top)
// swaying in the wind, for the way home's backdrops
// (scenes/props/sea/land_backdrop.gd). Each ROW shifts sideways by whole pixels,
// more the further it is from the anchor, so the crown bends rather than the
// whole sprite sliding, and nothing is ever resampled between two pixels. The
// quad is widened by `pad` either side so a crown can lean past its own bitmap.
#include "res://assets/shaders/act3_land_wind.gdshaderinc"

// Pixels the far end leans at the height of a gust.
uniform float sway = 1.0;
uniform float phase = 0.0;
uniform float speed = 1.0;
// Anchored along the top (a canopy hanging down) instead of at the roots.
uniform bool from_top = false;
// Rows from the anchor to full sway; 0 = the bitmap's whole height.
uniform float reach = 0.0;
// A tree moves as one: the wind is read at its roots, not per pixel.
uniform bool whole = true;
uniform float pad = 3.0;

varying vec2 world;
varying vec2 origin;
varying vec4 tint;

void vertex() {
	float s = UV.x * 2.0 - 1.0;
	VERTEX.x += s * pad;
	UV.x += s * pad * TEXTURE_PIXEL_SIZE.x;
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	origin = MODEL_MATRIX[3].xy;
	tint = COLOR;
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = floor(UV * size);
	float away = from_top ? px.y : size.y - 1.0 - px.y;
	float k = clamp(away / max(reach > 0.0 ? reach : size.y - 1.0, 1.0), 0.0, 1.0);
	float w = land_wind(whole ? origin.x : world.x, TIME * speed, phase);
	float dx = round(sway * k * k * w);
	vec2 uv = (vec2(px.x - dx, px.y) + 0.5) * TEXTURE_PIXEL_SIZE;
	if (uv.x < 0.0 || uv.x > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, uv) * tint;
	}
}
