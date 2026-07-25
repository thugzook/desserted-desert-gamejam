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
	Projectile.Lane.ABOVE,
	Projectile.Lane.LEFT,
	Projectile.Lane.RIGHT,
	Projectile.Lane.HEAD_LEFT,
	Projectile.Lane.HEAD_RIGHT,
]
## How far above the player's center "head height" is, in pixels. With rule-based
## dodging this is pure presentation — it just has to READ as "at the head":
## roughly -8 to -20 for the 44px placeholder box.
@export var head_offset := -18.0
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
	var home := player.home_position

	# Anchored to home_position: every lane is a fixed, axis-aligned approach so
	# the player can learn each one's answer (LANE_ANSWERS in player.gd decides).
	var from: Vector2
	var toward: Vector2
	match lane:
		Projectile.Lane.ABOVE:
			from = home + Vector2(0.0, -spawn_radius)
			toward = home
		Projectile.Lane.LEFT:
			from = home + Vector2(-spawn_radius, 0.0)
			toward = home
		Projectile.Lane.RIGHT:
			from = home + Vector2(spawn_radius, 0.0)
			toward = home
		Projectile.Lane.HEAD_LEFT:
			from = home + Vector2(-spawn_radius, head_offset)
			toward = from + Vector2.RIGHT  # horizontal — reads as "at the head"
		Projectile.Lane.HEAD_RIGHT:
			from = home + Vector2(spawn_radius, head_offset)
			toward = from + Vector2.LEFT

	var projectile: Projectile = projectile_scene.instantiate()
	projectile.setup(attack, lane, from, toward, despawn_radius)
	add_child(projectile)
