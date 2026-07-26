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
## Hard cap on threatening shots on screen at once — YOUR density lever. The
## spawner holds fire at the cap (and fires the moment a slot frees). Dodged,
## parried, and despawned shots don't count against it.
@export var max_alive := 6

@export_group("Placement")
## How far off-screen attacks appear.
@export var spawn_radius := 720.0
## TUNE: which lanes are in the deck (see Projectile.Lane — the dodge that beats
## each lane lives in player.gd's LANE_ANSWERS). Duplicate an entry to make that
## lane more common (e.g. two ABOVEs = overheads twice as likely). Remove one to retire it.
@export var lanes: Array[Projectile.Lane] = [
	Projectile.Lane.ABOVE_LEFT,
	Projectile.Lane.ABOVE_RIGHT,
	Projectile.Lane.ABOVE_CENTER,
	Projectile.Lane.FEET_LEFT,
	Projectile.Lane.FEET_RIGHT,
	Projectile.Lane.HEAD_LEFT,
	Projectile.Lane.HEAD_RIGHT,
]

## How far a shot travels from the screen centre before it deletes itself.
## Must comfortably exceed spawn_radius or attacks vanish before they arrive.
@export var despawn_radius := 1500.0

var _next_in := 0.0


func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING or attacks.is_empty() or player == null:
		return
	_next_in -= delta
	if _next_in <= 0.0 and _alive_count() < max_alive:
		# At the cap, _next_in stays ≤ 0, so we fire the instant a slot frees.
		_spawn()
		_next_in = current_interval()


## Threatening shots currently on screen (ghosted/deflected ones are done fighting).
func _alive_count() -> int:
	var n := 0
	for child in get_children():
		if child is Projectile and not child.dodged and not child.deflected:
			n += 1
	return n


## Linear ramp from start_interval down to min_interval over ramp_seconds.
## FLAIR: swap this for a Curve export if you want a shape other than a straight line.
func current_interval() -> float:
	var t: float = clampf(Game.time_survived / ramp_seconds, 0.0, 1.0)
	return lerpf(start_interval, min_interval, t)


func _spawn() -> void:
	var attack: ProjectileData = attacks.pick_random()
	var lane: Projectile.Lane = lanes.pick_random()
	var player_center := player.home_position
	# Offsets from centre, not absolute positions — Godot's Y grows DOWNWARD, so
	# up (head) is negative and down (feet) is positive. Derived from the sprite,
	# so resizing the player re-aims every lane automatically.
	var head_offset_y := -(player.player_size.y / 2)
	var feet_offset_y := player.player_size.y / 2
	
	var center_offset_x := player.player_size.x / 2

	# Anchored to home_position: every lane is a fixed, axis-aligned approach so
	# the player can learn each one's answer (LANE_ANSWERS in player.gd decides).
	var from: Vector2
	var toward: Vector2
	match lane:
		Projectile.Lane.ABOVE_CENTER:
			from = player_center + Vector2(0.0, -spawn_radius)
			toward = player_center
		Projectile.Lane.ABOVE_LEFT:
			from = player_center + Vector2(-center_offset_x, -spawn_radius)
			toward = player_center + Vector2(-center_offset_x, 0.0)
		Projectile.Lane.ABOVE_RIGHT:
			from = player_center + Vector2(center_offset_x, -spawn_radius)
			toward = player_center + Vector2(center_offset_x, 0.0)
		Projectile.Lane.FEET_LEFT:
			from = player_center + Vector2(-spawn_radius, feet_offset_y)
			toward = player_center + Vector2(0.0, feet_offset_y)
		Projectile.Lane.FEET_RIGHT:
			from = player_center + Vector2(spawn_radius, feet_offset_y)
			toward = player_center + Vector2(0.0, feet_offset_y)
		Projectile.Lane.HEAD_LEFT:
			from = player_center + Vector2(-spawn_radius, head_offset_y)
			toward = from + Vector2.RIGHT  # horizontal — reads as "at the head"
		Projectile.Lane.HEAD_RIGHT:
			from = player_center + Vector2(spawn_radius, head_offset_y)
			toward = from + Vector2.LEFT

	var projectile: Projectile = projectile_scene.instantiate()
	projectile.setup(attack, lane, from, toward, despawn_radius)
	add_child(projectile)
