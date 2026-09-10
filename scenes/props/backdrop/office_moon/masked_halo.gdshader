shader_type canvas_item;
render_mode unshaded, blend_add;
#include "res://scenes/props/backdrop/office_moon/window_mask.gdshaderinc"
varying vec4 item_tint;
void vertex() { item_tint = COLOR; }
void fragment() {
 COLOR = item_tint * texture(TEXTURE, UV);
 COLOR.a *= glass_alpha(UV);
}
