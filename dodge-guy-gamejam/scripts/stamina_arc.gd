extends Control
## FLAIR: segmented arc around the player, Deadlock-style (see docs/UI-mock.jpg).
## Currently plain pips — colors, gaps, glow, and a drain animation are yours.
##
## Placement note: this lives on the HUD CanvasLayer, positioned beside the player's
## home position in main.tscn. The Camera2D is fixed, so screen == world coordinates
## and a hand-placed offset stays put.

## Fallback pip count before the first stamina_changed arrives. The HUD overrides
## this from the player's max_stamina — tune the bar count there, not here.
@export var segments := 4
## Distance from this node's origin to the pips.
@export var radius := 42.0
## How fat each pip is.
@export var thickness := 5.0
## How much of a circle the arc covers.
@export var arc_degrees := 140.0


func _draw() -> void:
	var count: int = get_meta("segments", segments)
	var filled: int = get_meta("filled", count)
	var partial: float = get_meta("partial", 0.0)
	var step := deg_to_rad(arc_degrees) / float(count)
	var start := deg_to_rad(-90.0 - arc_degrees * 0.5)
	var gap := 0.06
	var track := Color(1, 1, 1, 0.15)
	var lit := Color(1, 1, 1, 0.9)
	for i in count:
		var pip_start := start + i * step
		var pip_end := pip_start + step - gap
		# The empty slot, always drawn — you can see what you're waiting on.
		draw_arc(Vector2.ZERO, radius, pip_start, pip_end, 8, track, thickness)
		if i < filled:
			draw_arc(Vector2.ZERO, radius, pip_start, pip_end, 8, lit, thickness)
		elif i == filled and partial > 0.0:
			## FLAIR: the bar recharging — sweeps a little further every tick.
			draw_arc(Vector2.ZERO, radius, pip_start,
				lerpf(pip_start, pip_end, partial), 8, lit, thickness)
