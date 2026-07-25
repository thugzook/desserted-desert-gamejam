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

@export_group("Placement")
## How far off-screen attacks appear.
@export var spawn_radius := 720.0
## Start of the arc attacks come from, in degrees. 180 = straight left.
## Godot's Y points down, so 180→360 is the TOP half — nothing comes up through the ground.
@export var spawn_angle_from := 180.0
## End of that arc, in degrees. 360 = straight right.
@export var spawn_angle_to := 360.0
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
	var angle := randf_range(deg_to_rad(spawn_angle_from), deg_to_rad(spawn_angle_to))
	var from := player.home_position + Vector2.from_angle(angle) * spawn_radius

	# Aimed at home_position, not the player's CURRENT position: attacks commit to
	# where you were, so moving away is what saves you.
	var projectile: Projectile = projectile_scene.instantiate()
	projectile.setup(attack, from, player.home_position, despawn_radius)
	add_child(projectile)
