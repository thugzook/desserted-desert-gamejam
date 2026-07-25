class_name Spawner
extends Node2D
## Picks attacks and throws them at the player. Difficulty ramp = 3 numbers.
##
## Coordinate assumption: this node sits at (0, 0) in main.tscn, so its children's
## local positions ARE world/screen positions and the player's home_position can be
## used directly. Move the Spawner and the spawn ring moves with it.

@export var projectile_scene: PackedScene
## TUNE: your attack designs. Drag .tres files here.
@export var attacks: Array[ProjectileData] = []
@export var player: Player

@export_group("Difficulty")
## Seconds between attacks at the start of a run. Higher = gentler opening.
@export var start_interval := 1.6
## Seconds between attacks once fully ramped. The floor of the difficulty curve.
@export var min_interval := 0.45
## How long the ramp from start_interval to min_interval takes.
@export var ramp_seconds := 90.0

## Where an attack can come from. Every lane is axis-aligned, so each one has a
## clean answer: ABOVE falls straight down your column (sidestep it — ducking
## keeps you in its path), LEFT/RIGHT fly at body height, HEAD_* fly at head
## height so a duck (S) passes clean under them.
enum Lane { ABOVE, LEFT, RIGHT, HEAD_LEFT, HEAD_RIGHT }

@export_group("Placement")
## How far off-screen attacks appear.
@export var spawn_radius := 720.0
## TUNE: which lanes are in the deck. Duplicate an entry to make that lane more
## common (e.g. two ABOVEs = overheads twice as likely). Remove one to retire it.
@export var lanes: Array[Lane] = [Lane.ABOVE, Lane.LEFT, Lane.RIGHT, Lane.HEAD_LEFT, Lane.HEAD_RIGHT]
## How far above the player's center "head height" is, in pixels. Must stay inside
## the TOP HALF of the 44px hurtbox (roughly -8 to -20): too high and head shots
## whiff a standing player, too low and they stop reading as "duck this".
@export var head_offset := -18.0
## How far a shot travels from the screen centre before it deletes itself.
## Must comfortably exceed spawn_radius or attacks vanish before they arrive.
@export var despawn_radius := 1500.0

var _next_in := 0.0


func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING or attacks.is_empty() or player == null:
		return
	_next_in -= delta
	if _next_in <= 0.0:
		_spawn()
		_next_in = current_interval()


## Linear ramp from start_interval down to min_interval over ramp_seconds.
## FLAIR: swap this for a Curve export if you want a shape other than a straight line.
func current_interval() -> float:
	var t: float = clampf(Game.time_survived / ramp_seconds, 0.0, 1.0)
	return lerpf(start_interval, min_interval, t)


func _spawn() -> void:
	var attack: ProjectileData = attacks.pick_random()
	var lane: Lane = lanes.pick_random()
	var home := player.home_position

	# Anchored to home_position, not the player's CURRENT position: attacks commit
	# to where you live, so moving away is what saves you. Directions are axis-
	# aligned (never aimed at the player) so a head-height shot STAYS at head
	# height — that's what makes ducking under it possible.
	var from: Vector2
	var toward: Vector2
	match lane:
		Lane.ABOVE:
			from = home + Vector2(0.0, -spawn_radius)
			toward = home
		Lane.LEFT:
			from = home + Vector2(-spawn_radius, 0.0)
			toward = home
		Lane.RIGHT:
			from = home + Vector2(spawn_radius, 0.0)
			toward = home
		Lane.HEAD_LEFT:
			from = home + Vector2(-spawn_radius, head_offset)
			toward = from + Vector2.RIGHT  # horizontal — passes over a ducked player
		Lane.HEAD_RIGHT:
			from = home + Vector2(spawn_radius, head_offset)
			toward = from + Vector2.LEFT

	var projectile: Projectile = projectile_scene.instantiate()
	projectile.setup(attack, from, toward, despawn_radius)
	add_child(projectile)
