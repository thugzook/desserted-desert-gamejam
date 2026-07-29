@tool   # runs in the editor too, so the idle pose previews without pressing F5
class_name PlayerArt
extends Sprite2D
## The player's drawn body: one image per dodge direction, swapped by player.gd.
## Purely cosmetic — nothing in here decides anything. LANE_ANSWERS in player.gd
## is still the sole judge of whether a dodge worked, so wrong art can never make
## you take a hit.
##
## It rides on the Sprite box, so it inherits the dodge nudge and the i-frame
## blink for free. Leave any slot empty and that direction falls back to idle —
## the game runs fine with NO images assigned at all (you just see the grey box).
##
## TUNE: drag a PNG into each slot below.

@export_group("Poses")
## Standing still. Every dodge snaps back to this one when its window closes.
## Also what the editor previews — the setter refreshes the canvas on assign.
@export var idle_texture: Texture2D:
	set(value):
		idle_texture = value
		if Engine.is_editor_hint():
			show_idle()
## While dodging left (A / ←).
@export var dodge_left_texture: Texture2D
## While dodging right (D / →).
@export var dodge_right_texture: Texture2D
## While dodging up (Space / ↑) — the jump pose.
@export var dodge_up_texture: Texture2D
## While dodging down (S / ↓) — the duck pose.
@export var dodge_down_texture: Texture2D

@export_group("Fit")
## How tall every pose is drawn, in pixels. Each image is scaled to this height
## (aspect kept), so drawings of different sizes still line up. Raise = bigger
## player. 0 = draw each image at its own native size. In game it applies on the
## next pose change; in the editor the preview rescales as you type.
@export var art_height := 200.0:
	set(value):
		art_height = value
		if Engine.is_editor_hint():
			show_idle()
## ON: a direction with no image of its own borrows the OPPOSITE side's image,
## mirrored — one sidestep drawing covers both left and right. Left/right only.
## OFF: a missing image just shows idle.
@export var mirror_missing_side := true
## ON: every pose stands on the same ground line — bottom edges align with idle's
## feet, so a short duck squats DOWN instead of floating at chest height.
## OFF: all poses share a centre.
@export var anchor_feet := true

@export_group("Per-Pose Height")
## Each slot: height in pixels for THAT pose only. 0 = use the shared Art Height.
## This is how one drawing reads smaller — e.g. set the duck to ~120 so crouching
## actually looks low.
@export var idle_height := 0.0:
	set(value):
		idle_height = value
		if Engine.is_editor_hint():
			show_idle()
@export var dodge_left_height := 0.0
@export var dodge_right_height := 0.0
@export var dodge_up_height := 0.0
@export var dodge_down_height := 0.0


func _ready() -> void:
	show_idle()


## Show the pose for a dodge heading `direction`. Unfilled directions fall back
## to idle, so a half-finished art set still plays.
func show_dodge(direction: Vector2) -> void:
	var pose := _pose_for(direction)
	var height := _height_for(direction)
	var flip := false
	if pose == null and mirror_missing_side and direction.x != 0.0:
		var mirrored := _pose_for(-direction)
		if mirrored != null:
			pose = mirrored
			height = _height_for(-direction)   # the borrowed drawing keeps its own tuning
			flip = true
	if pose == null:
		pose = idle_texture
		height = idle_height
	_apply(pose, flip, height)


func show_idle() -> void:
	_apply(idle_texture, false, idle_height)


func _pose_for(direction: Vector2) -> Texture2D:
	match direction:
		Vector2.LEFT:
			return dodge_left_texture
		Vector2.RIGHT:
			return dodge_right_texture
		Vector2.UP:
			return dodge_up_texture
		Vector2.DOWN:
			return dodge_down_texture
	return null


func _height_for(direction: Vector2) -> float:
	match direction:
		Vector2.LEFT:
			return dodge_left_height
		Vector2.RIGHT:
			return dodge_right_height
		Vector2.UP:
			return dodge_up_height
		Vector2.DOWN:
			return dodge_down_height
	return 0.0


func _apply(pose: Texture2D, flip: bool, pose_height := 0.0) -> void:
	texture = pose
	flip_h = flip
	offset = Vector2.ZERO
	if pose == null:
		return
	# Normalising every pose to one height is what lets you redraw a frame at a
	# different canvas size without re-tuning the scene. A per-pose height (if set)
	# wins over the shared Art Height.
	var native := float(pose.get_height())
	var target := pose_height if pose_height > 0.0 else art_height
	if target > 0.0 and native > 0.0:
		scale = Vector2.ONE * (target / native)
	else:
		scale = Vector2.ONE
	# Feet on the ground: idle's bottom edge sits art_height/2 below this node, so
	# push every pose down until its bottom lands on that same line. offset is in
	# texture pixels (pre-scale), hence the divide.
	if anchor_feet and art_height > 0.0 and native > 0.0:
		offset.y = (art_height * 0.5) / scale.y - native * 0.5
