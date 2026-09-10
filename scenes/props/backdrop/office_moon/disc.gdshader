shader_type canvas_item;
render_mode unshaded;
#include "res://scenes/props/backdrop/office_moon/window_mask.gdshaderinc"
// A shared 16-pixel lunar surface: crisp silhouette and restrained crater shading.
varying vec4 item_tint;
void vertex() { item_tint = COLOR; }
void fragment() {
 vec2 p = (floor(UV * 16.0) + 0.5) / 16.0;
 float d = distance(p, vec2(0.5));
 float crater = step(distance(p, vec2(0.32,0.38)),0.12) * 0.16;
 crater += step(distance(p, vec2(0.62,0.64)),0.16) * 0.12;
 crater += step(distance(p, vec2(0.65,0.28)),0.07) * 0.1;
 vec4 tint = item_tint;
 COLOR = vec4(vec3(0.79,0.88,1.0) * (1.0-crater), step(d,0.48) * glass_alpha(UV)) * tint;
}
