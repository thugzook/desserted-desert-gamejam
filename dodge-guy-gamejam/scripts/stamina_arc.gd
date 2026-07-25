extends Control
## FLAIR: segmented arc around the player, Deadlock-style (see docs/UI-mock.jpg).
## Currently plain pips — colors, gaps, glow, and a drain animation are yours.
##
## Placement note: this lives on the HUD CanvasLayer, positioned beside the player's
## home position in main.tscn. The Camera2D is fixed, so screen == world coordinates
## and a hand-placed offset stays put.

## How many pips the bar is chopped into. More = finer read, less punchy.
@export var segments := 8
## Distance from this node's origin to the pips.
@export var radius := 42.0
## How fat each pip is.
@export var thickness := 5.0
## How much of a circle the arc covers.
@export var arc_degrees := 140.0


func _draw() -> void:
	var fill: float = get_meta("fill", 1.0)
	var step := deg_to_rad(arc_degrees) / float(segments)
	var start := deg_to_rad(-90.0 - arc_degrees * 0.5)
	for i in segments:
		var lit := (float(i) / float(segments)) < fill
		var color := Color(1, 1, 1, 0.9) if lit else Color(1, 1, 1, 0.15)
		draw_arc(Vector2.ZERO, radius, start + i * step,
			start + (i + 1) * step - 0.06, 8, color, thickness)
