shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	// Persian handwriting begins at the right and progresses leftward.
	COLOR.a *= step(1.0 - progress, UV.x);
}
