@tool   # runs in the editor too, so you can see the oval while you position it
class_name PlayerShadow
extends Node2D
## The blob shadow under the player. Purely cosmetic — nothing here decides anything.
##
## It never leaves the ground. player.gd feeds it how far the body has LIFTED off
## its resting spot and how far it has SLID sideways; the oval shrinks and fades
## as the body rises, which is the whole "he's airborne" read. The Y radius is
## squashed well below the X radius so it lies flat in the ground plane instead
## of reading as a ball under his feet.
##
## TUNE: everything below. Drag this node to the player's feet in the editor —
## the oval draws live, so you can see where it lands.

@export_group("Shape")
## Oval size in pixels at ground level: x = half-width, y = half-depth. Keep y
## far under x — that squash IS the perspective. Raise x for a broader stance.
@export var radius := Vector2(62.0, 16.0):
	set(value):
		radius = value
		queue_redraw()
## Colour and opacity at ground level. Lower the alpha for a softer, dustier
## shadow; raise it for a hard midday one.
@export var color := Color(0.0, 0.0, 0.0, 0.35):
	set(value):
		color = value
		queue_redraw()
## Points around the oval. LOWER = chunkier and more faceted, which sits better
## with pixel art; raise for a smooth ellipse.
@export_range(6, 48) var segments := 24:
	set(value):
		segments = value
		queue_redraw()

@export_group("Jump Response")
## Lift in pixels at which the shadow bottoms out at min_scale. Set this to about
## your dodge_distance.y so a full jump uses the whole range.
@export var lift_reference := 70.0
## How small the shadow gets at the top of a jump. LOWER = reads as more height.
@export var min_scale := 0.45
## Ceiling on how much it grows while ducking (the body drops nearer the floor).
@export var max_scale := 1.15
## How much it fades at the top of a jump. 0 = never fades, 1 = gone entirely.
@export_range(0.0, 1.0) var fade_with_height := 0.55
## How much the shadow tracks a left/right dodge. 1 = stays exactly under the
## body; 0 = stays rooted to the spot while he leans off it.
@export_range(0.0, 1.0) var follow_horizontal := 1.0

var _home := Vector2.ZERO
var _scale := 1.0
var _fade := 1.0


func _ready() -> void:
	_home = position


## Called by player.gd every frame. `lift` is pixels the body sits ABOVE its
## resting spot (negative while ducking); `slide` is pixels it has moved sideways.
func set_lift(lift: float, slide: float) -> void:
	var t := lift / lift_reference if lift_reference > 0.0 else 0.0
	_scale = clampf(lerpf(1.0, min_scale, t), min_scale, max_scale)
	_fade = 1.0 - clampf(t, 0.0, 1.0) * fade_with_height
	position.x = _home.x + slide * follow_horizontal
	queue_redraw()


func _draw() -> void:
	var points := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		points.append(Vector2(cos(a) * radius.x, sin(a) * radius.y) * _scale)
	draw_colored_polygon(points, Color(color.r, color.g, color.b, color.a * _fade))
