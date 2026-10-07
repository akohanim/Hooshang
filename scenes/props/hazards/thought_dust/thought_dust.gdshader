shader_type canvas_item;
render_mode unshaded;
uniform sampler2D occupancy : filter_nearest, repeat_disable;
uniform vec2 grid_size;
uniform float clock = 0.0;
uniform vec2 grid_origin = vec2(0.0);
uniform float lobe_speed = 0.5;
uniform float center_speed = 0.6;

float hash_cell(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float occupied(vec2 cell) {
	vec2 size = grid_size;
	if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= size.x || cell.y >= size.y) { return 0.0; }
	return texture(occupancy, (cell + 0.5) / grid_size).a;
}
float tuft(vec2 p, float rotation, float radius, float seed) {
	float angle = atan(p.y, p.x) - rotation;
	float fringe = 0.28 * sin(angle * 5.0 + seed) + 0.18 * sin(angle * 9.0 - seed);
	return length(p) - radius - fringe;
}
void fragment() {
	// Evaluate at native pixel centres, even when the viewport is upscaled.
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE * 8.0) + 0.5;
	vec2 cell = floor(pixel / 8.0);
	float distance_to_dust = 100.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = cell + vec2(float(x), float(y));
			if (occupied(c) > 0.5) {
				vec2 p = pixel - (c + 0.5) * 8.0;
				float seed = hash_cell(c + grid_origin) * 6.283185;
				float d = tuft(p, clock * center_speed + seed, 3.5, seed);
				// Connect adjacent centres before outlining, so a strip is one mass.
				if (occupied(c + vec2(1.0, 0.0)) > 0.5) {
					vec2 bridge = abs(p - vec2(4.0, 0.0)) - vec2(4.0, 2.8);
					d = min(d, max(bridge.x, bridge.y));
				}
				if (occupied(c + vec2(0.0, 1.0)) > 0.5) {
					vec2 bridge = abs(p - vec2(0.0, 4.0)) - vec2(2.8, 4.0);
					d = min(d, max(bridge.x, bridge.y));
				}
				// Four diagonal lobes. Base and overlay counter-rotate, like DustGraphic.
				for (int i = 0; i < 4; i++) {
					float a = 0.785398 + float(i) * 1.570796;
					vec2 direction = vec2(cos(a), sin(a));
					vec2 corner = sign(direction);
					// Four mutually painted cells share a filled corner, never a pinhole.
					if (occupied(c + vec2(corner.x, 0.0)) > 0.5 &&
						occupied(c + vec2(0.0, corner.y)) > 0.5 && occupied(c + corner) > 0.5) {
						vec2 box = abs(p - corner * 4.0) - vec2(4.1);
						d = min(d, max(box.x, box.y));
					}
					vec2 q = p - direction * 1.5;
					float r = seed + float(i) * 1.71 + clock * lobe_speed;
					d = min(d, tuft(q, r, 2.5, seed));
					d = min(d, tuft(q, -r, 2.3, seed + 2.0));
				}
				distance_to_dust = min(distance_to_dust, d);
			}
		}
	}
	float noise = hash_cell(pixel + grid_origin * 8.0 + floor(clock * 5.0));
	vec3 body = mix(vec3(0.065, 0.035, 0.075), vec3(0.16, 0.07, 0.12), noise * 0.45);
	vec3 rim = mix(vec3(0.40, 0.08, 0.16), vec3(0.80, 0.24, 0.30), noise);
	// Union first, outline second: touching cells never acquire internal red seams.
	COLOR = vec4(distance_to_dust > -0.8 ? rim : body, distance_to_dust < 0.15 ? 1.0 : 0.0);
}
