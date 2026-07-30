// Cobblestone floor with a faked 3D-camera perspective, plus the darkening and
// anti-tiling from background_detile.gdshader.
//
// Perspective math is "2D-perspective" by Hei (MIT license):
//   https://godotshaders.com/shader/2d-perspective/
// Adapted here so it works on a REGION-TILED sprite: Hei's projection assumes UV
// runs 0..1, but the de-tiler needs UV to run PAST 1.0 (that's what makes
// floor(UV) a per-tile cell index). So UV is normalised to 0..1 for the
// projection, then rescaled back into tile space before the de-tile block.
//
// Only the `floor` node uses this. The flat background sprites keep
// background_detile.gdshader.
//
// TUNE: everything below is a slider on the node's ShaderMaterial in the Inspector.
shader_type canvas_item;

// MUST match the node's Region Rect (Inspector -> Sprite2D -> Region -> Rect):
// x, y, width, height. Everything else is derived from it, so cobble.png's own
// size never has to be hardcoded. Wrong values here = wrong perspective bounds.
uniform vec4 region_rect = vec4(0.0, 0.0, 743.0, 451.0);

// --- perspective (Hei) -------------------------------------------------------
// Camera field of view. Lower = flatter, longer-lens look. Higher = more extreme
// convergence toward the vanishing point.
uniform float fov : hint_range(1.0, 179.0) = 90.0;
// Throw away anything that projects behind the camera. Leave this on.
uniform bool cull_back = true;
// Tilt toward/away from the camera. THIS is the "lay the floor down" knob.
uniform float x_rot : hint_range(-180.0, 180.0) = 0.0;
// Swivel left/right around the vertical axis.
uniform float y_rot : hint_range(-180.0, 180.0) = 0.0;
// 0 = the image keeps its size when unrotated, but can draw outside its rect once
// rotated. 1 = shrink the content so a full rotation never clips.
uniform float inset : hint_range(0.0, 1.0) = 0.0;

// --- look (same three knobs as background_detile) ----------------------------
// 0 = full brightness, 1 = black. 0.5 = the "50% darker" default.
uniform float darkness : hint_range(0.0, 1.0) = 0.5;
// How much each tile's brightness randomly drifts from its neighbours.
// 0 = every tile identical (obvious grid). Higher = patchier, less uniform.
uniform float variation_strength : hint_range(0.0, 1.0) = 0.35;
// ON: each tile independently has a 50% chance to mirror horizontally and
// vertically. Cheapest way to hide a single repeating tile.
uniform bool randomize_flip = true;

varying flat vec2 o;
varying vec3 p;

// NOTE: PI is already a built-in constant in Godot 4 — Hei's original declared
// its own, which is a "Redefinition of 'PI'" compile error here. Don't re-add it.
//
// Likewise, tile_count / uv_origin are computed inline in each entry point below
// rather than in a helper function: Godot only exposes built-ins like
// TEXTURE_PIXEL_SIZE inside vertex()/fragment(), never in user-defined functions.

// Cheap deterministic pseudo-random in [0, 1) — same cell always gives the same
// value, so the pattern doesn't shimmer or change between frames.
// (Parameter is `h`, not `p`: `p` is the perspective varying above.)
float hash21(vec2 h) {
	h = fract(h * vec2(123.34, 456.21));
	h += dot(h, h + 45.32);
	return fract(h.x * h.y);
}

// Creates rotation matrix
void vertex() {
	// How many times the source texture repeats across the quad, and where the
	// region starts in UV space. Both fall out of region_rect + the texture size.
	vec2 tile_count = region_rect.zw * TEXTURE_PIXEL_SIZE;
	vec2 uv_origin = region_rect.xy * TEXTURE_PIXEL_SIZE;
	// Region tiling makes UV run 0..tile_count; the projection wants 0..1.
	vec2 nuv = (UV - uv_origin) / tile_count;

	float sin_b = sin(y_rot / 180.0 * PI);
	float cos_b = cos(y_rot / 180.0 * PI);
	float sin_c = sin(x_rot / 180.0 * PI);
	float cos_c = cos(x_rot / 180.0 * PI);

	mat3 inv_rot_mat;
	inv_rot_mat[0][0] = cos_b;
	inv_rot_mat[0][1] = 0.0;
	inv_rot_mat[0][2] = -sin_b;

	inv_rot_mat[1][0] = sin_b * sin_c;
	inv_rot_mat[1][1] = cos_c;
	inv_rot_mat[1][2] = cos_b * sin_c;

	inv_rot_mat[2][0] = sin_b * cos_c;
	inv_rot_mat[2][1] = -sin_c;
	inv_rot_mat[2][2] = cos_b * cos_c;

	float t = tan(fov / 360.0 * PI);
	p = inv_rot_mat * vec3((nuv - 0.5), 0.5 / t);
	float v = (0.5 / t) + 0.5;
	p.xy *= v * inv_rot_mat[2].z;
	o = v * inv_rot_mat[2].xy;

	// region_rect.zw, not 1.0 / TEXTURE_PIXEL_SIZE: the quad is the REGION's size,
	// not the source image's. (Hei's "mismatched sizes" note.) This inflates the
	// quad to give the projection room; fragment() clips the visible result back.
	VERTEX += (nuv - 0.5) * region_rect.zw * t * (1.0 - inset);
}

void fragment() {
	if (cull_back && p.z <= 0.0) {
		discard;
	}
	// The perspective divide. Centred on 0, so +/-0.5 are the quad's edges.
	vec2 nuv = (p.xy / p.z) - o;
	// Clip to the sprite's rect, so the floor stays a distinct receding slab.
	float inside = step(max(abs(nuv.x), abs(nuv.y)), 0.5);

	// Back into tile space so floor()/fract() still land on real tile cells.
	vec2 tile_count = region_rect.zw * TEXTURE_PIXEL_SIZE;
	vec2 uv_origin = region_rect.xy * TEXTURE_PIXEL_SIZE;
	vec2 tuv = (nuv + 0.5) * tile_count + uv_origin;

	vec2 cell = floor(tuv);
	vec2 local = fract(tuv);
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
	COLOR = vec4(tex.rgb * jitter * (1.0 - darkness), tex.a * inside);
}
