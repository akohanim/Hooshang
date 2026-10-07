shader_type canvas_item;
// Recessed office sash. Bright horizontal bevels read as standable platforms
// at gameplay scale, so only the vertical jambs catch a restrained highlight.
varying vec4 item_tint;
void vertex() { item_tint = COLOR; }
void fragment() {
 vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
 vec2 p = floor(UV * size);
 float edge = min(min(p.x, size.x-1.0-p.x), min(p.y,size.y-1.0-p.y));
 float side = min(p.x, size.x-1.0-p.x);
 // Dark wall reveal around a flush frame, with no projecting sill or cap.
 vec3 steel = vec3(0.075,0.09,0.115);
 if (edge < 1.0) steel = vec3(0.055,0.065,0.085);
 else if (side >= 3.0 && side < 5.0 && p.y >= 3.0 && p.y < size.y-3.0)
  steel = side < 4.0 ? vec3(0.18,0.235,0.28) : vec3(0.115,0.16,0.20);
 else if (edge >= 4.0) steel = vec3(0.105,0.13,0.165);
 vec4 tint = item_tint;
 COLOR = vec4(steel, 1.0-step(5.0,edge)) * tint;
}
