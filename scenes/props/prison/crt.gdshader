shader_type canvas_item;
// HOOSHANG 64's TV glass, laid over the game picture: a dark line between every
// row of the game's own pixels (the picture is 120 rows tall on this rect),
// and a soft vignette into the curved corners of an old tube.
uniform float rows = 120.0;
uniform float line_strength = 0.28;
uniform float vignette = 0.55;

void fragment() {
	float row = fract(UV.y * rows);
	float line = smoothstep(0.62, 0.95, row) * line_strength;
	vec2 d = UV - 0.5;
	float v = smoothstep(0.32, 0.72, length(d * vec2(1.0, 0.9))) * vignette;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(line + v, 0.0, 0.85));
}
