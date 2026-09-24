shader_type canvas_item;
// Atmospheric separation applies only to the landmark plates, not gameplay.
uniform float saturation : hint_range(0.0, 1.0) = 0.65;
uniform float contrast : hint_range(0.0, 1.0) = 0.58;
uniform vec4 haze : source_color = vec4(0.76, 0.80, 0.76, 1.0);
varying vec4 item_tint;
void vertex() {
	item_tint = COLOR;
}
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 paint = mix(vec3(luminance), source.rgb, saturation);
	paint = mix(haze.rgb, paint, contrast);
	COLOR = vec4(paint, source.a) * item_tint;
}
