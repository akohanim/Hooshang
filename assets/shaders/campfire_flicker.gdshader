shader_type canvas_item;
render_mode unshaded;

uniform float flicker_time = 0.0;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
// The held frame is column 1 of the six-frame 16x20 source sheet.
void fragment() {
	vec2 local_uv = vec2(UV.x * 6.0 - 1.0, UV.y);
	float height = clamp((0.8 - local_uv.y) / 0.8, 0.0, 1.0);
	float sway = sin(flicker_time * 8.1 + local_uv.y * 11.0)
		+ 0.55 * sin(flicker_time * 13.7 - local_uv.y * 7.0);
	// Only the upper tongues curl. The logs and flame base never move.
	float dx = floor(sway * height * 1.4 + 0.5);
	float dy = floor(sin(flicker_time * 9.3 + local_uv.x * 9.0) * height + 0.5);
	vec2 sample_uv = local_uv + vec2(dx / 16.0, dy / 20.0);
	vec2 bounded = clamp(sample_uv, vec2(0.5 / 16.0, 0.5 / 20.0), vec2(15.5 / 16.0, 19.5 / 20.0));
	vec4 flame = texture(TEXTURE, vec2((bounded.x + 1.0) / 6.0, bounded.y));
	float flow = 0.90 + 0.10 * sin(local_uv.y * 21.0 + flicker_time * 14.0 + local_uv.x * 5.0);
	flame.rgb *= mix(1.0, flow, step(local_uv.y, 0.8));
	COLOR = tint * flame;
}
