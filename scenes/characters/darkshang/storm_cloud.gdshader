shader_type canvas_item;

uniform float storm_time = 0.0;
uniform float storm_strength = 0.055;
uniform float sheet_frame = 0.0;
uniform float pixel_size = 72.0;
varying vec4 tint;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec2 local = vec2(UV.x * 3.0 - sheet_frame, UV.y);
	float t = storm_time;
	// Keep the blinking eyes readable while different cloud lobes roll past.
	float eyes = 1.0 - smoothstep(0.65, 1.5, length((local - vec2(0.5, 0.49)) / vec2(0.21, 0.10)));
	float border = smoothstep(0.0, 0.08, min(min(local.x, 1.0-local.x), min(local.y, 1.0-local.y)));
	// Slow domain drift carries the small curls, avoiding a uniform jelly wobble.
	vec2 drift = vec2(noise(local * 2.5 + t * 0.12), noise(local * 2.5 - t * 0.16 + 9.0)) - 0.5;
	vec2 flowing = local + drift * 0.35;
	vec2 flow = vec2(
		noise(flowing * 4.0 + vec2(t * 0.24, -t * 0.18)),
		noise(flowing * 4.0 + vec2(-t * 0.2, t * 0.28) + 17.0)) * 2.0 - 1.0;
	flow += vec2(sin(local.y * 13.0 + t * 0.9), cos(local.x * 15.0 - t * 0.7)) * 0.3;
	float breath = sin(t * 1.15) * 0.018 + sin(t * 0.63 + 1.7) * 0.012;
	vec2 breathing = (local - vec2(0.5, 0.55)) * vec2(-breath, breath * 0.6);
	vec2 warped = local + breathing * (1.0 - eyes) + flow * storm_strength * border * (1.0 - eyes);
	// Quantize the moving sample to the native artwork footprint, preserving
	// crisp game pixels instead of smearing the high-resolution source.
	warped = (floor(warped * pixel_size) + 0.5) / pixel_size;
	warped = clamp(warped, vec2(0.001), vec2(0.999));
	vec4 ink = texture(TEXTURE, vec2((sheet_frame + warped.x) / 3.0, warped.y));
	float rolling_shadow = noise(local * 7.0 + vec2(-t * 0.3, t * 0.22));
	ink.rgb *= mix(0.82 + rolling_shadow * 0.48, 1.0, eyes);
	// A travelling violet rim reveals volume without flashing the whole cloud.
	float rim = smoothstep(0.01, 0.12, max(ink.r, max(ink.g, ink.b))) * (1.0 - eyes);
	float glimmer = pow(max(0.0, sin(local.y * 5.0 - local.x * 3.0 + t * 0.85)), 4.0);
	ink.rgb += vec3(0.018, 0.022, 0.045) * rim * glimmer;
	COLOR = ink * tint;
}
