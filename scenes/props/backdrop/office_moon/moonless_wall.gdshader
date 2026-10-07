shader_type canvas_item;
// Moon pixels belong to the selectable prefab, never to the repeating wall.
uniform int moon_count = 0;
uniform vec4 moon_regions[64];
uniform int cleared_window_count = 0;
uniform vec4 cleared_windows[32];
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	vec4 paint = texture(TEXTURE, UV);
	for (int i = 0; i < moon_count; i++) {
		vec4 r = moon_regions[i] + vec4(-2.0, -2.0, 4.0, 4.0);
		if (pixel.x >= r.x && pixel.y >= r.y && pixel.x < r.x + r.z && pixel.y < r.y + r.w) {
			paint = texture(TEXTURE, vec2((r.x - 2.0) * TEXTURE_PIXEL_SIZE.x, UV.y));
		}
	}
	for (int i = 0; i < cleared_window_count; i++) {
		vec4 r = cleared_windows[i];
		if (pixel.x >= r.x && pixel.y >= r.y && pixel.x < r.x + r.z && pixel.y < r.y + r.w) {
			paint = texture(TEXTURE, vec2(max(1.0, r.x - 12.0) * TEXTURE_PIXEL_SIZE.x, UV.y));
		}
	}
	COLOR = tint * paint;
}
