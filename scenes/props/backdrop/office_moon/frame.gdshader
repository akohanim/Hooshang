shader_type canvas_item;
// Steel office sash, aligned to whole source pixels and open onto the sky.
varying vec4 item_tint;
void vertex() { item_tint = COLOR; }
void fragment() {
 vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
 vec2 p = floor(UV * size);
 float edge = min(min(p.x, size.x-1.0-p.x), min(p.y,size.y-1.0-p.y));
 vec3 steel = vec3(0.16,0.23,0.29);
 if (edge < 1.0) steel = vec3(0.065,0.10,0.14);
 else if (edge < 2.0) steel = vec3(0.40,0.52,0.59);
 else if (edge < 4.0) steel = vec3(0.24,0.33,0.39);
 vec4 tint = item_tint;
 COLOR = vec4(steel, 1.0-step(5.0,edge)) * tint;
}
