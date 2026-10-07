shader_type canvas_item;
uniform float progress = 0.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
vec2 frame_uv(vec2 uv, float frame) {
	vec2 cell = vec2(mod(frame, 4.0), floor(frame / 4.0));
	return (cell + clamp(uv, vec2(0.002), vec2(0.998))) / vec2(4.0, 2.0);
}
float eye_height(float frame) {
	if (frame < 0.5) { return 0.5372; }
	if (frame < 1.5) { return 0.4473; }
	if (frame < 2.5) { return 0.3593; }
	if (frame < 3.5) { return 0.3176; }
	if (frame < 5.5) { return 0.2223; }
	return 0.1999;
}
void fragment() {
	float phase = progress * 7.0;
	float frame = floor(phase);
	float blend = smoothstep(0.0, 1.0, fract(phase));
	vec2 uv = UV;
	// A final curl pulls the loose edges inward as the human silhouette forms.
	float edge = smoothstep(0.12, 0.42, abs(uv.x - 0.5));
	uv.x += sin(uv.y * 16.0 - progress * 12.0) * 0.022 * sin(progress * 3.14159) * edge;
	uv = (floor(uv * 72.0) + 0.5) / 72.0;
	// Register the eyes before blending: otherwise adjacent poses produce four eyes.
	float next_frame = min(frame + 1.0, 7.0);
	float eye_a = eye_height(frame);
	float eye_b = eye_height(next_frame);
	float eye = mix(eye_a, eye_b, blend);
	float head = 1.0 - smoothstep(0.16, 0.4, abs(uv.y - eye));
	vec4 a = texture(TEXTURE, frame_uv(uv + vec2(0.0, (eye_a - eye) * head), frame));
	vec4 b = texture(TEXTURE, frame_uv(uv + vec2(0.0, (eye_b - eye) * head), next_frame));
	// Premultiplied interpolation keeps translucent smoke dark, without halos.
	float alpha = mix(a.a, b.a, blend);
	vec3 color = mix(a.rgb * a.a, b.rgb * b.a, blend) / max(alpha, 0.0001);
	COLOR = vec4(color, alpha) * tint;
}
