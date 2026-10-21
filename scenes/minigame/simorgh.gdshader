shader_type canvas_item;
// SUPER SIMORGH: the whole first-person picture, ray-marched per PIXEL on the
// GPU (simorgh_game.gd moves the camera, the lights and Darkshang). The rect is
// the game's 160x120 SubViewport, so every pixel here is one screen pixel.
//
// It starts as a bright, psychedelic Persian corridor and is EATEN: Darkshang
// comes up behind, and `dark` drains the colour out of everything — black
// veins through the tiles, the sky to a dead eclipse, the fog closing in,
// the mihrab niches opening into eyes. Behind his front (`dark_x`) the world
// is gone; at the front he stands, a cloud that keeps becoming Hooshang's own
// shape (his real sheet, assets/characters/darkshang/darkshang.png) and back,
// in a pixel dissolve. As he closes (`prox`) tendrils grow in from the edges
// of the screen; `consume` closes them; `scare` is his face, for a few frames.
//
// The course is a HEIGHTFIELD on a grid (map_tex, one texel per cell):
//   R  ground height  (0 = a pit; else (R-64)/32 units, so 64 = floor level)
//   G  floating block bottom, B its top (B = 0: no block)
//   A  materials: ground's in the low nibble, the floating block's in the high

uniform sampler2D map_tex : filter_nearest;
uniform sampler2D ds_tex : filter_nearest;
uniform vec2 cam_pos = vec2(2.5, 3.5);
uniform float cam_z = 0.55;
uniform float cam_angle = 0.0;
uniform float clock = 0.0;
uniform float trip = 0.4;
uniform float flash = 0.0;
uniform vec3 flash_color = vec3(1.0, 0.25, 0.3);
uniform float dark = 0.0;
uniform float dark_x = -100.0;
uniform float ds_size = 2.5;
uniform float morph = 0.0;
uniform float prox = 0.0;
uniform float scare = 0.0;
uniform float consume = 0.0;
uniform float flicker = 0.0;
// Hooshang himself, seen in the third-person opening (hidden once the view is
// his own): assets/minigame/simorgh/hooshang_sheet.png, 32x48 cells, the cell
// to draw, and whether to mirror it (the side frames face east).
uniform sampler2D hoo_tex : filter_nearest;
uniform vec3 hoo_pos = vec3(-100.0, 0.0, 0.0);
uniform ivec2 hoo_cell = ivec2(0, 0);
uniform float hoo_flip = 0.0;
// x, y (cells), z (centre height), kind + phase / 10
// kinds: 1 a light (coin), 5 a light popping from a star block, 7 a sparkle
uniform vec4 sprites[12];
uniform int sprite_count = 0;

const vec2 RES = vec2(160.0, 120.0);
const ivec2 MAP = ivec2(160, 8);

const vec3 COBALT = vec3(0.10, 0.20, 0.58);
const vec3 NAVY = vec3(0.05, 0.07, 0.22);
const vec3 TURQ = vec3(0.20, 0.70, 0.70);
const vec3 GOLD = vec3(0.95, 0.74, 0.30);
const vec3 IVORY = vec3(0.95, 0.90, 0.76);
const vec3 CRIMSON = vec3(0.62, 0.09, 0.14);
const vec3 OCHRE = vec3(0.72, 0.50, 0.30);
const vec3 SAFFRON = vec3(0.98, 0.62, 0.12);
const vec3 VOID = vec3(0.035, 0.015, 0.05);
const vec3 BRUISE = vec3(0.28, 0.17, 0.48);

vec3 hue_rot(vec3 c, float a) {
	vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

mat2 rot(float a) {
	return mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
}

float star8(vec2 c) {
	vec2 a = abs(c);
	return min(max(a.x, a.y), (a.x + a.y) * 0.7071068);
}

float hash(float n) {
	return fract(sin(n * 91.7) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

// ------------------------------------------------------------ surfaces --

vec3 inscription(vec2 uv) {
	if (uv.y < 0.12 || uv.y > 0.9) return GOLD;
	float s = uv.x * 22.0;
	float r = hash(floor(s));
	float fx = fract(s);
	float y = (uv.y - 0.12) / 0.78;
	bool stem = abs(fx - 0.5) < 0.13 && y > 0.75 - 0.6 * r && y < 0.85;
	bool base = abs(y - 0.8) < 0.07 && r > 0.25;
	bool dt = r > 0.7 && length(vec2(fx - 0.2, y - 0.2) * vec2(1.0, 1.6)) < 0.12;
	return (stem || base || dt) ? IVORY : COBALT;
}

vec3 girih(vec2 uv) {
	vec2 c = fract(uv * 2.0) - 0.5;
	float s = star8(c);
	vec2 q = 0.5 - abs(c);
	vec3 col = COBALT;
	if (q.x + q.y < 0.17) col = TURQ;
	if (s < 0.30) col = TURQ;
	if (s < 0.18) col = COBALT * 1.25;
	if (star8(rot(0.3927) * c) < 0.08) col = GOLD;
	if (abs(s - 0.30) < 0.035) col = IVORY;
	return col;
}

vec3 kaleido(vec2 d) {
	float r = length(d);
	float a = atan(d.y, d.x) + clock * 0.5;
	float seg = TAU / 8.0;
	a = abs(mod(a, seg) - seg * 0.5);
	vec2 k = vec2(cos(a), sin(a)) * r;
	float pat = sin(k.x * 40.0 - clock * 3.0) + sin(k.y * 55.0 + clock * 2.0);
	vec3 c = mix(NAVY, hue_rot(GOLD, r * 10.0 - clock * 1.5), smoothstep(-0.2, 1.2, pat));
	return mix(c, hue_rot(TURQ, clock), smoothstep(0.9, 1.9, pat));
}

// An eye, looking out of a niche once the dark has come (d: -0.5..0.5).
vec3 eye(vec2 d, float seed, out float lit) {
	lit = 0.0;
	float blink = step(0.93, fract(clock * 0.31 + seed));
	vec2 e = d / vec2(0.34, 0.2 * (1.0 - blink));
	if (length(e) > 1.0) return VOID;
	lit = 1.0;
	vec2 look = vec2(sin(clock * 0.7 + seed * 6.0) * 0.08, 0.0);
	float r = length(d - look);
	vec3 col = vec3(0.85, 0.82, 0.75);
	if (r < 0.15) col = vec3(0.7, 0.05, 0.08);
	if (abs(d.x - look.x) < 0.025 && r < 0.14) col = vec3(0.0);
	return col;
}

// Pointed-arch niche: a mihrab, opening on a kaleidoscope — or, as the dark
// takes the place, on an eye. `lit` marks pixels that ignore the darkness.
vec3 niche(vec2 uv, float seed, out float lit) {
	lit = 0.0;
	vec3 col = girih(uv * vec2(1.0, 2.2));
	float spring = 0.56;
	float R = 0.42;
	float Ro = R + 0.06;
	bool outer = uv.x > 0.14 && uv.x < 0.86 && uv.y < 0.97
		&& (uv.y > spring || (length(uv - vec2(0.14 + Ro, spring)) < Ro && length(uv - vec2(0.86 - Ro, spring)) < Ro));
	bool inner = uv.x > 0.2 && uv.x < 0.8
		&& (uv.y > spring || (length(uv - vec2(0.2 + R, spring)) < R && length(uv - vec2(0.8 - R, spring)) < R));
	if (outer) col = GOLD;
	if (inner) {
		if (dark > 0.35 + 0.3 * seed) col = eye(uv - vec2(0.5, 0.62), seed, lit);
		else col = kaleido(uv - vec2(0.5, 0.6));
	}
	return col;
}

// The way out: an arch full of white light that the dark cannot touch.
vec3 door(vec2 uv, out float lit) {
	lit = 0.0;
	float spring = 0.5;
	float R = 0.42;
	bool inner = uv.x > 0.12 && uv.x < 0.88
		&& (uv.y > spring || (length(uv - vec2(0.12 + R, spring)) < R && length(uv - vec2(0.88 - R, spring)) < R));
	if (!inner) return mix(girih(uv * vec2(1.0, 2.2)), GOLD, 0.3);
	lit = 1.0;
	float g = 0.85 + 0.15 * sin(clock * 3.0 + uv.y * 9.0);
	return mix(vec3(1.0, 0.92, 0.7), vec3(1.0), smoothstep(0.1, 0.35, abs(uv.x - 0.5))) * g;
}

vec3 bannai(vec2 uv) {
	vec2 b = vec2(uv.x * 4.0, uv.y * 6.0);
	float row = floor(b.y);
	b.x += mod(row, 2.0) * 0.5;
	vec2 f = fract(b);
	float id = floor(b.x);
	if (f.y < 0.14 || f.x < 0.07) return vec3(0.36, 0.25, 0.17);
	if (mod(abs(id - 2.0) + abs(row - 3.0), 4.0) < 1.0) return TURQ;
	return OCHRE * (0.88 + 0.2 * hash(id * 7.0 + row));
}

vec3 carpet(vec2 f) {
	vec2 q = fract(f / 3.0) - 0.5;
	q *= 1.0 + 0.2 * trip * sin(clock * 1.4 - length(q) * 10.0);
	vec2 a = abs(q);
	float m = max(a.x, a.y);
	vec3 col = CRIMSON;
	vec2 g = fract(q * 10.0) - 0.5;
	if (length(g) < 0.14) col = CRIMSON * 0.6;
	vec2 cq = vec2(0.40) - a;
	if (cq.x + cq.y < 0.15) col = NAVY;
	float lz = a.x + a.y * 1.5;
	if (lz < 0.27) col = NAVY;
	if (lz < 0.21) col = IVORY;
	if (star8(q * 1.3) < 0.09) col = CRIMSON;
	if (abs(lz - 0.27) < 0.016) col = GOLD;
	if (m > 0.40) {
		col = NAVY;
		vec2 bq = fract(f * 2.0) - 0.5;
		if (length(bq) < 0.17) col = SAFFRON;
	}
	if (abs(m - 0.40) < 0.015 || abs(m - 0.475) < 0.012) col = IVORY;
	return col;
}

vec3 dome(vec2 f) {
	vec2 q = fract(f / 4.0) - 0.5;
	float r = max(length(q), 0.002);
	if (r > 0.48) {
		vec2 s = fract(f * 1.5) - 0.5;
		return star8(s) < 0.12 ? GOLD : NAVY;
	}
	float ang = atan(q.y, q.x);
	float u = log(r) * 3.0 + clock * 0.25 * (0.4 + trip);
	float v = ang / TAU * 16.0;
	float l1 = abs(fract(u + v) - 0.5);
	float l2 = abs(fract(u - v) - 0.5);
	vec3 col = mix(IVORY * 0.85, OCHRE, smoothstep(0.0, 0.45, r));
	if (l1 > 0.36 && l2 > 0.36) col = TURQ;
	if (min(l1, l2) < 0.07) col = GOLD;
	if (r < 0.05) col = SAFFRON;
	return col;
}

vec3 bevel(vec2 uv, vec3 base) {
	float e = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	if (e < 0.07) return base * 0.55;
	if (uv.y < 0.14 || uv.x < 0.14) return base * 1.15;
	return base;
}

vec3 surface(int mat, int face, vec3 p, ivec2 hc, out float lit) {
	lit = 0.0;
	bool flat_face = face >= 2;
	float along = face == 0 ? p.y : p.x;
	vec2 uv = flat_face ? fract(p.xy) : vec2(fract(along), 1.0 - fract(p.z));
	float seed = hash2(vec2(hc));
	if (mat == 11 && !flat_face && p.z < 2.4) return door(vec2(fract(along), 1.0 - p.z / 2.4), lit);
	if (mat == 1 || mat == 2 || mat == 10 || mat == 11) {
		if (flat_face) return GOLD * 0.8;
		if (mat != 1 && p.z < 2.2 && p.z > 0.0) return niche(vec2(fract(along), 1.0 - p.z / 2.2), seed, lit);
		if (p.z > 2.5) return inscription(vec2(fract(along), (3.0 - p.z) * 2.0));
		if (p.z < 0.12 && p.z > 0.0) return GOLD;
		return girih(vec2(fract(along), 1.0 - fract(p.z)));
	}
	if (mat == 0) return kaleido(fract(p.xy * 0.5) - 0.5) * 0.6 * (1.0 - dark);
	if (mat == 4) {
		if (face == 2) return carpet(p.xy);
		return bannai(uv) * clamp(0.45 + (p.z + 6.0) * 0.09, 0.2, 1.0);
	}
	if (mat == 3) return bannai(uv);
	if (mat == 5) {
		vec3 col = bevel(uv, GOLD);
		float s = star8(rot(clock * 1.5) * (uv - 0.5));
		if (s < 0.24) col = IVORY;
		if (s < 0.15) { col = SAFFRON; lit = 0.6; }
		return col;
	}
	if (mat == 6) return bevel(uv, vec3(0.42, 0.28, 0.18));
	if (mat == 7) {
		vec2 b = vec2(uv.x * 2.0, uv.y * 4.0);
		b.x += mod(floor(b.y), 2.0) * 0.5;
		vec2 f = fract(b);
		return (f.y < 0.12 || f.x < 0.08) ? vec3(0.30, 0.16, 0.10) : OCHRE * 1.05;
	}
	if (mat == 8) {
		if (flat_face) {
			float r = length(fract(p.xy * 0.5) - 0.5);
			return r < 0.32 ? NAVY * 0.6 : (r < 0.4 ? GOLD : TURQ);
		}
		vec3 col = TURQ * (0.5 + 0.7 * sin(fract(along * 0.5) * 3.14159));
		if (fract(along * 4.0) < 0.12) col *= 0.75;
		return col;
	}
	if (mat == 9) {
		vec3 col = bevel(uv, vec3(0.62, 0.44, 0.30));
		if (star8(uv - 0.5) < 0.12) col = TURQ;
		return col;
	}
	return IVORY;
}

// The dark taking a surface: everything behind his front is gone, black veins
// run ahead of it (further the darker it gets), and rot spreads everywhere.
vec3 corrupt(vec3 col, vec3 p, float lit) {
	float front = dark_x + 0.5 * vnoise(vec2(p.y * 2.0 + clock * 0.8, p.z * 2.0 - clock));
	if (p.x < front) {
		float smoke = vnoise(vec2(p.y * 3.0 - clock * 0.6, p.z * 3.0 + p.x));
		return mix(VOID, BRUISE * 0.55, smoke * smoke);
	}
	if (lit > 0.5) return col;
	float reach = 1.5 + 6.0 * dark;
	float k = 1.0 - (p.x - front) / reach;
	float vn = vnoise(vec2(p.x * 2.1 + p.z * 1.3, p.y * 2.3 - p.z * 1.7));
	float vein = abs(fract(vn * 4.0 + clock * 0.05) - 0.5);
	if (k > 0.0 && (k > 0.85 || vein < 0.16 * k)) return VOID;
	if (vein < 0.05 * dark) return mix(VOID, CRIMSON * 0.6, 0.25 + 0.25 * sin(clock * 3.0 + p.x));
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l) * vec3(0.55, 0.5, 0.7), dark * 0.85);
	return col * (1.0 - dark * 0.55);
}

vec3 sky(vec2 rd, float slope) {
	float el = slope / length(rd);
	vec3 low = hue_rot(SAFFRON, clock * 0.2 * trip);
	vec3 high = hue_rot(COBALT, -clock * 0.15 * trip);
	vec3 col = mix(low, high, smoothstep(-0.1, 0.7, el));
	if (slope > 0.02) {
		vec2 f = cam_pos + rd * (6.0 / slope);
		col = mix(col, hue_rot(dome(f * 0.5), trip * clock * 0.3), 0.45 * smoothstep(0.05, 0.5, el));
	}
	float k = atan(rd.y, rd.x) / TAU * 10.0;
	float l = fract(k) - 0.5;
	float sk = 0.03 + 0.11 * sqrt(max(0.0, 1.0 - pow(l / 0.28, 2.0))) + (abs(l) < 0.015 ? 0.17 : 0.0);
	float mn = abs(abs(l) - 0.42) < 0.018 ? 0.24 : 0.0;
	if (el < max(sk, mn)) col = NAVY * 1.3;
	// the dying sky: black, and a dead sun ringed red straight ahead
	vec3 dead = VOID * 0.7;
	vec3 d = normalize(vec3(rd, slope));
	float ring = dot(d, normalize(vec3(1.0, 0.0, 0.32)));
	if (ring > 0.985) dead = vec3(0.0);
	else if (ring > 0.975) dead = mix(CRIMSON, vec3(0.9, 0.2, 0.1), 0.5 + 0.5 * sin(clock * 2.0));
	else dead += CRIMSON * 0.25 * smoothstep(0.85, 0.975, ring);
	col = mix(col, dead, smoothstep(0.1, 0.7, dark));
	// behind him there is nothing at all, a wall of it as high as he is tall
	if (rd.x < 0.0) {
		float tc = (dark_x - cam_pos.x) / rd.x;
		if (tc > 0.0 && cam_z + slope * tc < ds_size * 1.6) col = VOID;
	}
	return col;
}

// ---------------------------------------------------------------- march --

vec4 cell_at(ivec2 m) {
	if (m.x < 0 || m.y < 0 || m.x >= MAP.x || m.y >= MAP.y) return vec4(160.0, 0.0, 0.0, 1.0);
	return floor(texelFetch(map_tex, m, 0) * 255.0 + 0.5);
}

float march(vec2 rd, float slope, out int mat, out int face, out vec3 hit, out ivec2 hc) {
	ivec2 m = ivec2(floor(cam_pos));
	vec2 dd = 1.0 / max(abs(rd), vec2(1e-5));
	ivec2 st = ivec2(rd.x < 0.0 ? -1 : 1, rd.y < 0.0 ? -1 : 1);
	vec2 sd = vec2(
		rd.x < 0.0 ? (cam_pos.x - float(m.x)) * dd.x : (float(m.x) + 1.0 - cam_pos.x) * dd.x,
		rd.y < 0.0 ? (cam_pos.y - float(m.y)) * dd.y : (float(m.y) + 1.0 - cam_pos.y) * dd.y);
	float tin = 0.0;
	int side = 0;
	mat = 0;
	face = 0;
	hit = vec3(0.0);
	hc = m;
	for (int i = 0; i < 110; i++) {
		float tout = min(sd.x, sd.y);
		vec4 c = cell_at(m);
		float hg = c.r < 0.5 ? -6.0 : (c.r - 64.0) / 32.0;
		int gm = int(mod(c.a, 16.0));
		int sm = int(floor(c.a / 16.0));
		float zin = cam_z + slope * tin;
		float zout = cam_z + slope * tout;
		float best = 1e9;
		int bm = 0;
		int bf = 0;
		if (i > 0 && zin < hg) { best = tin; bm = gm; bf = side; }
		else if (slope < 0.0 && zout < hg) { best = (hg - cam_z) / slope; bm = gm; bf = 2; }
		if (c.b > 0.5) {
			float b = (c.g - 64.0) / 32.0;
			float tp = (c.b - 64.0) / 32.0;
			if (i > 0 && zin >= b && zin <= tp && tin < best) { best = tin; bm = sm; bf = side; }
			if (slope < 0.0 && zin > tp && zout < tp) {
				float th = (tp - cam_z) / slope;
				if (th < best) { best = th; bm = sm; bf = 2; }
			}
			if (slope > 0.0 && zin < b && zout > b) {
				float th = (b - cam_z) / slope;
				if (th < best) { best = th; bm = sm; bf = 3; }
			}
		}
		if (best < 1e8) {
			mat = bm;
			face = bf;
			hit = vec3(cam_pos + rd * best, cam_z + slope * best);
			hc = m;
			return best;
		}
		if (m.x < 0 || m.y < 0 || m.x >= MAP.x || m.y >= MAP.y) break;
		tin = tout;
		if (sd.x < sd.y) { sd.x += dd.x; m.x += st.x; side = 0; }
		else { sd.y += dd.y; m.y += st.y; side = 1; }
	}
	return -1.0;
}

// ------------------------------------------------------------- Darkshang --

// His mass at billboard coordinates sp (-0.5..0.5, y down): 1 inside, and
// `lit` for his eyes. A purple-rimmed cloud and his own Hooshang-shaped body,
// dissolving into each other pixel by pixel as `morph` swings.
float darkshang(vec2 sp, out float lit, out float rim) {
	lit = 0.0;
	rim = 0.0;
	sp.x *= 1.0 + 0.12 * sin(clock * 2.3);
	float cloud = 0.0;
	float cd = 9.0;
	for (int k = 0; k < 7; k++) {
		float a = float(k) * 0.897 + clock * 0.35;
		vec2 c = vec2(cos(a) * 0.22, sin(a) * 0.13 + 0.06);
		float r = 0.17 + 0.04 * sin(clock * 1.7 + float(k) * 2.1);
		cd = min(cd, length(sp - c) - r);
	}
	cd = min(cd, length(sp - vec2(0.0, -0.12)) - 0.2);
	if (cd < 0.0) cloud = 1.0;
	float human = 0.0;
	vec4 tx = vec4(0.0);
	vec2 uv = vec2(sp.x * 1.5 + 0.5, sp.y + 0.5);
	if (uv.x >= 0.0 && uv.x < 1.0 && uv.y >= 0.0 && uv.y < 1.0) {
		ivec2 frame = ivec2(int(mod(floor(clock * 4.0), 4.0)), 1);   // row 1: the frames with his eyes open
		tx = texelFetch(ds_tex, frame * ivec2(32, 48) + ivec2(uv * vec2(32.0, 48.0)), 0);
		human = step(0.5, tx.a);
	}
	float dither = hash2(floor(sp * 64.0) + floor(clock * 8.0));
	bool as_human = morph > dither;
	float inside = as_human ? human : cloud;
	if (inside < 0.5) return 0.0;
	if (as_human) {
		if (dot(tx.rgb, vec3(0.333)) > 0.6) lit = 1.0;
		else if (dot(tx.rgb, vec3(0.333)) > 0.2) rim = 1.0;
	} else {
		vec2 e = abs(sp - vec2(0.0, -0.1)) - vec2(0.075, 0.0);
		if (length(e) < 0.035) lit = 1.0;
		if (cd > -0.03) rim = 1.0;
	}
	// more eyes open on him the darker it gets
	vec2 g = floor(sp * 14.0);
	vec2 f = fract(sp * 14.0) - 0.5;
	float h = hash2(g);
	if (h > 1.0 - dark * 0.22 && length(f * vec2(1.0, 1.6)) < 0.35 && fract(clock * 0.4 + h * 7.0) > 0.12) lit = 1.0;
	return 1.0;
}

// ------------------------------------------------------------------ scene --

vec3 scene(vec2 px) {
	vec2 dir = vec2(cos(cam_angle), sin(cam_angle));
	vec2 plane = vec2(-dir.y, dir.x) * 0.66;
	vec2 rd = dir + plane * (2.0 * px.x / RES.x - 1.0);
	float horizon = RES.y * 0.5;
	float slope = -(px.y - horizon) / RES.y;

	int mat;
	int face;
	vec3 hit;
	ivec2 hc;
	float t = march(rd, slope, mat, face, hit, hc);
	vec3 fog = mix(hue_rot(vec3(0.14, 0.05, 0.24), clock * 0.3 * trip), VOID, dark);
	float fog_far = mix(10.0, 3.2, dark);
	vec3 col;
	float depth = 1e9;
	float lit = 0.0;
	if (t < 0.0) {
		col = sky(rd, slope);
	} else {
		col = surface(mat, face, hit, hc, lit);
		if (face == 1) col *= 0.82;
		if (face == 3) col *= 0.7;
		if (lit < 0.5) {
			col = hue_rot(col, trip * (1.6 * sin(clock * 0.6 + t * 0.7) + clock * 0.25));
			col *= 1.0 + 0.3 * trip * sin(t * 3.0 - clock * 3.5);
		}
		col = corrupt(col, hit, lit);
		float fk = clamp(t / fog_far, 0.0, 1.0);
		if (lit < 0.5) col = mix(col, fog, fk * fk);
		col *= 1.0 - flicker * (lit > 0.5 ? 0.0 : 0.92);
		depth = t;
	}

	float invdet = 1.0 / (plane.x * dir.y - dir.x * plane.y);
	// Darkshang, standing at his front
	vec2 drel = vec2(dark_x - 0.6, 3.5) - cam_pos;
	float dtx = invdet * (dir.y * drel.x - dir.x * drel.y);
	float dty = invdet * (-plane.y * drel.x + plane.x * drel.y);
	if (dty > 0.12 && dty < depth + 1.0) {
		float size = RES.y / dty * ds_size;
		vec2 sp = (px - vec2(RES.x * 0.5 * (1.0 + dtx / dty), horizon - (ds_size * 0.45 - cam_z) / dty * RES.y)) / size;
		// his aura: the purple glow his cloud form wears in the art
		float aura = exp(-max(length(sp * vec2(1.5, 1.0)) - 0.32, 0.0) * 7.0);
		col += BRUISE * 0.55 * aura * (1.0 - flicker * 0.6);
		if (abs(sp.x) < 0.5 && abs(sp.y) < 0.5) {
			float elit;
			float rim;
			if (darkshang(sp, elit, rim) > 0.5) {
				col = elit > 0.5 ? vec3(1.0, 0.95, 0.78) : (rim > 0.5 ? BRUISE * (0.7 + 0.3 * sin(clock * 4.0)) : vec3(0.0));
				if (elit < 0.5) col *= 1.0 - flicker * 0.9;
				depth = dty;
			}
		}
	}
	// Hooshang, for the opening shot
	vec2 hrel = hoo_pos.xy - cam_pos;
	float htx = invdet * (dir.y * hrel.x - dir.x * hrel.y);
	float hty = invdet * (-plane.y * hrel.x + plane.x * hrel.y);
	if (hty > 0.2 && hty < depth) {
		float size = RES.y / hty * 0.82;
		vec2 sp = (px - vec2(RES.x * 0.5 * (1.0 + htx / hty), horizon - (hoo_pos.z + 0.41 - cam_z) / hty * RES.y)) / size;
		vec2 uv = vec2(sp.x * 1.5 + 0.5, sp.y + 0.5);
		if (hoo_flip > 0.5) uv.x = 1.0 - uv.x;
		if (uv.x >= 0.0 && uv.x < 1.0 && uv.y >= 0.0 && uv.y < 1.0) {
			vec4 tx = texelFetch(hoo_tex, hoo_cell * ivec2(32, 48) + ivec2(uv * vec2(32.0, 48.0)), 0);
			if (tx.a > 0.5) {
				float l = dot(tx.rgb, vec3(0.299, 0.587, 0.114));
				col = mix(tx.rgb, vec3(l) * vec3(0.6, 0.55, 0.75), dark * 0.6) * (1.0 - flicker * 0.92);
				depth = hty;
			}
		}
	}
	vec3 glow = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		if (i >= sprite_count) break;
		vec4 s = sprites[i];
		vec2 rel = s.xy - cam_pos;
		float tx = invdet * (dir.y * rel.x - dir.x * rel.y);
		float ty = invdet * (-plane.y * rel.x + plane.x * rel.y);
		if (ty < 0.12 || ty > depth) continue;
		float kind = floor(s.w);
		float scale = kind < 6.0 ? 0.5 : 0.25;
		float size = RES.y / ty * scale;
		vec2 sp = (px - vec2(RES.x * 0.5 * (1.0 + tx / ty), horizon - (s.z - cam_z) / ty * RES.y)) / size;
		float l = length(sp);
		glow += mix(GOLD, IVORY, dark) * 0.3 * exp(-l * 5.0) * clamp(3.0 / ty, 0.0, 1.0);
		if (abs(sp.x) > 0.5 || abs(sp.y) > 0.5) continue;
		if (kind > 6.5) {
			float k = (abs(sp.x) + 0.08) * (abs(sp.y) + 0.08);
			if (k < 0.03) { col = IVORY; depth = ty; }
			continue;
		}
		// a light: a little lamp-flame of gold, white at the heart
		vec2 q = sp;
		q.x /= max(abs(cos(clock * 4.0 + s.x)), 0.15);
		float r = length(q);
		if (r < 0.4) {
			col = r < 0.12 ? vec3(1.0) : (r < 0.3 ? mix(GOLD, IVORY, dark) : SAFFRON * 0.8);
			if (star8(q) < 0.14 && r > 0.12) col = IVORY;
			depth = ty;
		}
	}
	return col + glow;
}

// Darkshang's face, filling the screen for a frame or two.
vec3 face(vec2 px) {
	vec2 c = (px - RES * 0.5) / RES.y;
	c += (vec2(hash(floor(clock * 30.0)), hash(floor(clock * 30.0) + 3.0)) - 0.5) * 0.03;
	vec3 col = VOID + BRUISE * 0.12 * vnoise(c * 14.0 + clock * 3.0);
	float head = length(c * vec2(0.9, 0.8) - vec2(0.0, 0.02));
	if (head > 0.52) col = vec3(0.0);
	for (int k = 0; k < 2; k++) {
		float s = k == 0 ? -1.0 : 1.0;
		vec2 e = c - vec2(s * 0.16, -0.07);
		if (abs(e.y - e.x * s * 0.18) < 0.022 && abs(e.x) < 0.1) col = vec3(1.0, 0.96, 0.8);
	}
	vec2 m = c - vec2(0.0, 0.17);
	float curve = -0.11 + m.x * m.x * 1.4;
	if (abs(m.x) < 0.3 && abs(m.y - curve) < 0.03) {
		col = vec3(0.12, 0.0, 0.02);
		if (fract(m.x * 22.0) < 0.5 && m.y < curve) col = vec3(0.9, 0.88, 0.8);
	}
	return col;
}

void fragment() {
	vec2 px = floor(UV * RES) + 0.5;
	if (scare > 0.5) {
		COLOR = vec4(face(px), 1.0);
	} else {
		vec2 c = px - RES * 0.5;
		float sway = max(trip, dark * 0.7);
		c = rot(0.06 * sway * sin(clock * 0.45)) * c;
		c.x += sin(c.y * 0.09 + clock * 1.7) * 3.5 * sway;
		c.y += sin(c.x * 0.07 + clock * 1.3) * 2.5 * sway;
		vec2 w = c + RES * 0.5;
		vec3 col = scene(w);
		float split = max(trip - 0.45, 0.0) * 4.0 + prox * prox * 3.0;
		if (split > 0.4) {
			col.r = scene(w + vec2(split, 0.0)).r;
			col.b = scene(w - vec2(split, 0.0)).b;
		}
		// his tendrils, growing in from the edges as he comes
		vec2 q = px / RES - 0.5;
		float ang = atan(q.y, q.x);
		float edge = 0.62 - length(q * vec2(1.0, 0.75));
		float n = vnoise(vec2(ang * 5.0, clock * 0.6)) * 0.6 + vnoise(vec2(ang * 13.0, clock * 1.4)) * 0.4;
		float reach = prox * 0.36 + consume * 1.3;
		if (edge < reach * (0.25 + 0.95 * n)) col = edge < reach * (0.25 + 0.95 * n) - 0.02 ? vec3(0.0) : BRUISE * 0.6;
		col *= 1.0 - smoothstep(0.25, 0.7, length(q * vec2(1.0, 0.75))) * (0.25 + 0.55 * dark);
		col = mix(col, flash_color, clamp(flash, 0.0, 1.0));
		if (consume > 0.98) col = vec3(0.0);
		COLOR = vec4(col, 1.0);
	}
}
