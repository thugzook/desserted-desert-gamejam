class_name Torch
extends Node2D
## A burning torch. The node's origin IS the flame center — the sprite hangs
## below it via its offset — so the vignette can aim its light straight at
## `global_position`. Move/scale this node freely in main.tscn to reposition
## the light source.
## Art: torch_sheet.png, 5 frames split from opengameart.org's torch_anim.gif.

@export_group("Animation")
@export var fps := 10.0 ## Spritesheet frames per second. Raise for a busier flame.

var _clock := 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _process(delta: float) -> void:
	_clock += delta * fps
	_sprite.frame = int(_clock) % _sprite.hframes
