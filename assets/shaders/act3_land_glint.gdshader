shader_type canvas_item;
// Small life in the way home's backdrops (scenes/props/sea/land_backdrop.gd),
// one shader for three kinds of plane:
//   0 TWINKLE  sun on water: each glint (a few pixels wide) on its own clock,
//              lit, then out, then lit again somewhere else in the run.
//   1 PULSE    light shafts breathing, slowly, out of step along the room.
//   2 FALL     a waterfall: bright streaks running DOWN through its own pixels,
//              so the ribbon never leaves the shape it was painted in.

uniform int mode = 0;
uniform float speed = 1.0;

varying vec2 world;
varying vec4 tint;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = floor(UV * size);
	vec4 c = texture(TEXTURE, UV);
	if (mode == 0) {
		float h = hash(vec2(floor(px.x / 3.0), px.y));
		float t = fract(TIME * speed * (0.25 + 0.35 * h) + h * 11.0);
		c.a *= t < 0.42 ? 1.0 : (t < 0.5 ? 0.45 : 0.0);
	} else if (mode == 1) {
		c.a *= 0.72 + 0.28 * sin(TIME * speed * 0.55 + floor(world.x) * 0.045);
	} else {
		float f = fract((px.y - TIME * speed * 26.0) / 11.0 + hash(vec2(px.x, 3.0)) * 0.6);
		c.rgb = mix(c.rgb, vec3(0.96, 0.99, 1.0), f < 0.16 ? 0.55 : (f < 0.3 ? 0.18 : 0.0));
	}
	COLOR = c * tint;
}
