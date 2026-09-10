shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// Within each authored moon rectangle only the bright lunar pixels emit.
	// Keep the original pixel silhouette, excluding its dark sky corners.
	float mask = step(0.25, min(source.r, min(source.g, source.b)));
	COLOR = vec4(vec3(0.76, 0.88, 1.0), source.a * mask);
}
