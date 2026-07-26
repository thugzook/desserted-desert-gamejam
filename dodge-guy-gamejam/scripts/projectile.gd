class_name Projectile
extends Area2D
## Telegraph in place, then fly at where the player was. Configured entirely by a ProjectileData.

## Which direction this shot attacks from — the player's LANE_ANSWERS table maps
## each lane to the dodge direction that beats it.
enum Lane { ABOVE_LEFT, ABOVE_RIGHT, ABOVE_CENTER, FEET_LEFT, FEET_RIGHT, HEAD_LEFT, HEAD_RIGHT }

var data: ProjectileData
var lane: Lane = Lane.ABOVE_CENTER
var direction := Vector2.ZERO
var telegraph_left := 0.0
var deflected := false
var dodged := false
## Distance from the screen centre past which this cleans itself up.
## Handed over by the Spawner in setup() so the number lives on one Inspector.
var despawn_radius := 1500.0

var _pulse: Tween

@onready var sprite: ColorRect = $Sprite
@onready var shape: CollisionShape2D = $CollisionShape2D


## Called by the Spawner BEFORE add_child, so _ready() has everything it needs.
func setup(attack: ProjectileData, in_lane: Lane, from: Vector2, toward: Vector2, despawn_at: float) -> void:
	data = attack
	lane = in_lane
	position = from
	direction = (toward - from).normalized()
	telegraph_left = attack.telegraph_time
	despawn_radius = despawn_at


func _ready() -> void:
	sprite.color = data.color
	sprite.size = data.size
	sprite.position = -data.size * 0.5
	# A shape saved in the .tscn is SHARED by every instance of it — resizing it
	# here would resize every other projectile on screen. So each one gets its own.
	var box := RectangleShape2D.new()
	box.size = data.size
	shape.shape = box
	rotation = direction.angle()
	# FLAIR: the telegraph is just a pulse for now — a wind-up animation, a
	# warning line, or a sound would all read better. See docs/04 §2.
	_pulse = create_tween().set_loops()
	_pulse.tween_property(sprite, "modulate:a", data.pulse_min_alpha, data.pulse_rate)
	_pulse.tween_property(sprite, "modulate:a", 1.0, data.pulse_rate)


func _physics_process(delta: float) -> void:
	if telegraph_left > 0.0:
		telegraph_left -= delta
		if telegraph_left <= 0.0:
			_launch()
		return
	position += direction * data.speed * delta
	if position.distance_to(get_viewport_rect().size * 0.5) > despawn_radius:
		queue_free()


## Parried: fly back the way it came, faster, and stop being dangerous.
func deflect() -> void:
	if deflected:
		return
	deflected = true
	# deflect() runs inside the player's area_entered dispatch, where Godot blocks
	# direct collision-flag writes (the assignment silently fails and the parry
	# fires twice). set_deferred applies them safely at the end of the frame.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	direction = -direction
	data = data.duplicate()                      # don't mutate the shared .tres!
	data.speed *= data.deflect_speed_multiplier
	var spin := create_tween()
	spin.tween_property(self, "rotation", rotation + TAU, 0.4)


## Dodged fair and square: give up on hurting anyone, fade, and coast on through.
## (ghost_alpha 0 on the .tres makes dodged shots vanish outright.)
func ghost() -> void:
	if dodged or deflected:
		return
	dodged = true
	# Same rule as deflect(): we're inside the player's area_entered dispatch,
	# where direct collision-flag writes are silently blocked.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	sprite.modulate.a = data.ghost_alpha


## Telegraph over. The blink must STOP here — a solid rectangle is the cue that
## says "this one is live now", and it's the whole readability contract.
func _launch() -> void:
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	sprite.modulate.a = 1.0
