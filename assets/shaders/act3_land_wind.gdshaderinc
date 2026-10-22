// The way home's wind (scenes/props/sea/land_backdrop.gd), shared by the tree,
// canopy and grass shaders so one gust crosses them all: a slow swell plus a
// quicker flutter, both travelling left to right across the WORLD, so a tree on
// the left leans a moment before the grass beside it. -1..1.
float land_wind(float x, float t, float phase) {
	float swell = sin(t * 0.9 - x * 0.021 + phase);
	float flutter = sin(t * 2.3 - x * 0.057 + phase * 1.7);
	return swell * 0.7 + flutter * 0.3;
}
