// Cobblestone floor: darkens the tile and breaks up the repeat pattern.
// Works with texture_repeat=Enabled + a region_rect bigger than the source
// image (how background.gd's Sprite2D is already set up) — UV keeps counting
// past 1.0 once per tile, so floor(UV) is a free per-tile cell coordinate.
// TUNE: all three uniforms are sliders on the node's ShaderMaterial in the Inspector.
shader_type canvas_item;

// 0 = full brightness, 1 = black. 0.5 = the "50% darker" default.
uniform float darkness : hint_range(0.0, 1.0) = 0.5;
// How much each tile's brightness randomly drifts from its neighbours.
// 0 = every tile identical (obvious grid). Higher = patchier, less uniform.
uniform float variation_strength : hint_range(0.0, 1.0) = 0.35;
// ON: each tile independently has a 50% chance to mirror horizontally and
// vertically. Cheapest way to hide a single repeating tile — most seams
// vanish because neighbouring tiles rarely match edge-for-edge anymore.
uniform bool randomize_flip = true;

// Cheap deterministic pseudo-random in [0, 1) — same cell always gives the same
// value, so the pattern doesn't shimmer or change between frames.
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 cell = floor(UV);
	vec2 local = fract(UV);
	if (randomize_flip) {
		if (hash21(cell) > 0.5) {
			local.x = 1.0 - local.x;
		}
		if (hash21(cell + 17.0) > 0.5) {
			local.y = 1.0 - local.y;
		}
	}
	vec4 tex = texture(TEXTURE, cell + local);
	float jitter = 1.0 - variation_strength * 0.5 + hash21(cell + 91.7) * variation_strength;
	COLOR = vec4(tex.rgb * jitter * (1.0 - darkness), tex.a);
}
