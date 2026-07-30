shader_type canvas_item;
render_mode blend_premul_alpha;

// Screen-space torch light. Lives on a full-screen ColorRect on CanvasLayer 1
// — above the world (so it swallows projectiles) and below the HUD (layer 2,
// stays crisp). Tune it on the ColorRect's Material in the Inspector.
//
// Premultiplied-alpha blending is what makes this read as LIGHT rather than a
// grey film: the result is `scene * (1 - alpha) + rgb`, so one pass can both
// ADD warm orange at the flame (rgb, alpha 0) and crush the edges to true
// black (rgb 0, alpha 1). Don't switch to blend_mix — you lose the glow.
//
// `center` is aimed at the Torch's flame every frame by torch_vignette.gd —
// don't hand-edit it.

uniform vec2 center = vec2(0.5, 0.5);
uniform vec4 light_color : source_color = vec4(1.0, 0.55, 0.18, 1.0); // Firelight tint added at the flame.
uniform float radius : hint_range(0.0, 1.5) = 0.8; // Lit radius in screen-heights (0.8 lights ~80% of the screen and leaves the corners black). Raise to light more of the scene.
uniform float core : hint_range(0.0, 1.0) = 0.25; // Fraction of the radius that stays at full brightness. Raise for a bigger hot spot and a tighter falloff.
uniform float darkness : hint_range(0.0, 1.0) = 0.8; // Opacity of the dark. 1.0 = the outside is solid black and hides projectiles completely.
uniform float ambient : hint_range(0.0, 0.5) = 0.0; // Light floor outside the radius. Raise to let players faintly read incoming shots in the dark.
uniform float glow_strength : hint_range(0.0, 1.0) = 0.45; // How much orange light is ADDED near the flame. Raise for a hotter, brighter torch pool.
uniform float pixel_size : hint_range(1.0, 32.0) = 6.0; // Size of the light's blocks in screen pixels. Raise for a chunkier, more pixel-art edge.
uniform int light_steps : hint_range(2, 32) = 3; // Number of brightness bands. LOWER = harder, more banded pixel-art falloff.
uniform float flicker_speed : hint_range(0.0, 20.0) = 1.0; // Sputter rate. Raise for a more nervous flame.
uniform float flicker_amount : hint_range(0.0, 0.2) = 0.01; // How much the radius wobbles. Raise and the light breathes harder.
uniform float brightness_flicker : hint_range(0.0, 1.0) = 0.1; // How much the whole pool pulses. Raise for stormier light.

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	// Snap to a coarse grid first so every band edge lands on a block
	// boundary — this is what makes the falloff read as pixel art instead of
	// a smooth photographic gradient.
	vec2 blocks = SCREEN_PIXEL_SIZE * pixel_size;
	vec2 uv = (floor(UV / blocks) + 0.5) * blocks;

	// Aspect-correct so the light is a circle, not an oval. Distance ends up
	// in screen-heights: the top/bottom edges sit at 0.5, the corners at ~1.0.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float dist = length((uv - center) * vec2(aspect, 1.0));

	// Torch flicker: two sines beating at unrelated rates plus a stepped
	// random sputter — reads as firelight without any noise texture.
	float t = TIME * flicker_speed;
	float fl = sin(t) * 0.5 + sin(t * 2.7 + 1.3) * 0.3;
	fl += (hash(floor(t * 2.0)) - 0.5) * 0.6;

	float r = radius * (1.0 + fl * flicker_amount);
	float light = 1.0 - smoothstep(r * core, r, dist); // 1 at the flame, 0 past the radius.
	light = clamp(light * (1.0 + fl * brightness_flicker), 0.0, 1.0);

	float steps = float(light_steps);
	light = floor(light * steps + 0.5) / steps;
	light = max(light, ambient);

	// rgb ADDS firelight (premultiplied); alpha crushes what's left to black.
	COLOR = vec4(light_color.rgb * light * glow_strength, (1.0 - light) * darkness);
}
