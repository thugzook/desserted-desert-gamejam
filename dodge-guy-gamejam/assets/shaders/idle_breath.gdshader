// Breathing idle: gently stretches wide / squashes tall on a sine wave, with the
// feet pinned so the pose stays planted on the ground line.
// TUNE: both uniforms live on the Art node's material in the Inspector.
// To remove entirely: select Art, clear CanvasItem -> Material.
shader_type canvas_item;

// How deep each breath goes. 0.03 = 3% squash. More = cartoonier.
uniform float breath_amount : hint_range(0.0, 0.1) = 0.03;
// Breaths per ~2.5s at 2.5. Higher = faster, more nervous breathing.
uniform float breath_speed : hint_range(0.5, 8.0) = 2.5;

void vertex() {
	float t = sin(TIME * breath_speed);
	float feet = 0.5 / TEXTURE_PIXEL_SIZE.y; // bottom edge of the sprite
	VERTEX.x *= 1.0 + breath_amount * t; // inhale = wider...
	VERTEX.y = (VERTEX.y - feet) * (1.0 - breath_amount * t) + feet; // ...and shorter, feet pinned
}
