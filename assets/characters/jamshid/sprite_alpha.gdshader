shader_type canvas_item;
varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

// Generated sheets contain a faint translucent edge. Keep the opaque pixel
// silhouette clean when sampling at the game's small world resolution.
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	if (texel.a < 0.5) { discard; }
	COLOR = vertex_color * vec4(texel.rgb, 1.0);
}
