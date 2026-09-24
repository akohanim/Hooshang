shader_type canvas_item;
// Clip the disc at the landscape horizon, rather than drawing over the dunes.
uniform float horizon_uv = 2.0;
void fragment() {
	COLOR.a *= 1.0 - smoothstep(horizon_uv - 0.01, horizon_uv + 0.01, UV.y);
}
