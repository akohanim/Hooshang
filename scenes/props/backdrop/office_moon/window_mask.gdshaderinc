// Coordinates are in the window/background owner's local pixel space.
// Zero panes means opaque: new art must explicitly define its glass openings.
uniform int pane_count = 0;
uniform vec4 panes[32];
uniform vec4 sprite_rect = vec4(0.0);
float glass_alpha(vec2 uv) {
 vec2 p = sprite_rect.xy + uv * sprite_rect.zw;
 for (int i = 0; i < pane_count; i++) {
  vec4 r = panes[i];
  if (p.x >= r.x && p.y >= r.y && p.x < r.x+r.z && p.y < r.y+r.w) return 1.0;
 }
 return 0.0;
}
