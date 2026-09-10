shader_type canvas_item;
// Refraction for both water systems (Pond's tiled Sprite2D body and the
// painted Water TileMapLayer) — the first shader in this project. Every
// other transparent-over-a-backdrop effect here (SunShaft, WallPattern, the
// lemon/thought-hazard glows) gets away with a plain alpha-blended sprite or
// an unshaded additive one; none of them need to warp what is BEHIND them,
// which is the one thing alpha blending structurally cannot do — real water
// bends light, so whatever sits under the surface should visibly wobble, not
// just show through at a fixed spot tinted teal.
//
// PIXEL-SNAPPED ON PURPOSE. `screen_texture`'s own filter hint is
// filter_nearest, so a fractional UV offset does not blur the sampled pixel —
// it SNAPS to whichever whole screen pixel the offset lands on. That is what
// keeps this reading as pixel art rather than a smeared heat-haze: the
// background jumps a whole pixel at a time as the wave passes, the same
// chunky wobble a hand-animated water tile would use, not a continuous blur
// no pixel-art game would draw by hand.
//
// The offset is a sum of two sines at different axes/speeds rather than one,
// so the wobble does not read as a single wave sweeping in one direction —
// two independent frequencies beating against each other is what stops it
// looking like a scrolling texture and makes it look like turbulence.
//
// Applied to Pond's water via CanvasItem.use_parent_material on each tile
// sprite (one ShaderMaterial built once in pond.gd, not one per sprite) and
// directly as the Water TileMapLayer's own material (scripts/ldtk_water_layer.gd)
// — see either script for how the material is built and its uniforms are set.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;
// How far the sampled background shifts, in normalised screen-UV units. Kept
// small deliberately — CLAUDE.md's own "restrained, not noisy" rule for
// Act 2 gameplay art applies here too: this should read as a gentle ripple
// a player's eye catches without thinking about it, not a wild funhouse warp.
uniform float strength : hint_range(0.0, 0.02) = 0.006;
// Full wobble cycles per second, per axis.
uniform float speed : hint_range(0.0, 5.0) = 1.3;
// How many wave crests fit across the UNIT UV range — higher reads as choppier,
// smaller ripples; lower reads as one slow, broad swell.
uniform float frequency : hint_range(1.0, 40.0) = 14.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float wave_x = sin(UV.y * frequency + TIME * speed);
	float wave_y = sin(UV.x * frequency * 0.7 - TIME * speed * 0.8);
	vec2 offset = vec2(wave_x, wave_y) * strength;
	vec4 behind = texture(screen_texture, SCREEN_UV + offset);
	// The water's own alpha decides how much of the distorted background
	// shows through versus the water's own painted colour — same blend an
	// ordinary alpha-composited sprite would do, just against a warped
	// sample instead of a fixed one.
	COLOR = mix(behind, tex_color, tex_color.a);
	COLOR.a = 1.0;
}
