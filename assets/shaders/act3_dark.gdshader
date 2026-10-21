shader_type canvas_item;
// The Dark Floor (Act3_Level_12): the lights are out in the drowned office. One
// rect over the room, black except for a soft hole around Hooshang, ordered-
// dithered at its edge so the falloff stays pixel art. Drawn ABOVE the terrain
// and the water and BELOW the hazards and memories (act3_beats.gd raises them),
// so a thought's red rim always reads in the dark — fair, if frightening.

uniform vec2 centre = vec2(0.0);
uniform float radius = 44.0;
uniform float soft = 26.0;
uniform float strength = 0.94;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[x + y * 4]) + 0.5) / 16.0;
}

void fragment() {
	vec2 px = floor(world);
	float d = distance(px, floor(centre));
	float dark = smoothstep(radius, radius + soft, d);
	float dithered = step(bayer4(px), dark);
	COLOR = vec4(0.0, 0.0, 0.0, mix(dark, dithered, 0.6) * strength);
}
