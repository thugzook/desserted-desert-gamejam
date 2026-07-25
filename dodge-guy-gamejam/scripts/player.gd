class_name Player
extends Area2D
## The player. A dodge is a TIMED WINDOW with a DIRECTION RULE: press the right
## direction for the incoming lane while it arrives and the projectile is
## neutralized (it ghosts through you). The body's nudge is pure presentation —
## the collider never moves. Parry works even mid-dodge. Everything costs stamina.
##
## The dodge rulebook is LANE_ANSWERS below — one table, edit freely.
##
## TUNE: everything in the @export groups below. 60 physics ticks/sec, so
## frames / 60 = seconds. (5 frames = 0.08s, 9 frames = 0.15s, 12 frames = 0.20s)

enum State { HOME, DODGING, HIT, DEAD }

const ACTIONS := {
	"dodge_left": Vector2.LEFT,
	"dodge_right": Vector2.RIGHT,
	"dodge_up": Vector2.UP,
	"dodge_down": Vector2.DOWN,
}

## TUNE (design rule, not a number): which dodge direction beats which lane.
## The whole rulebook is this one table — "sidestep overheads, jump body shots,
## duck head shots." Add a Vector2 to a list to give a lane a second answer.
const LANE_ANSWERS := {
	Projectile.Lane.ABOVE: [Vector2.LEFT, Vector2.RIGHT],
	Projectile.Lane.LEFT: [Vector2.UP],
	Projectile.Lane.RIGHT: [Vector2.UP],
	Projectile.Lane.HEAD_LEFT: [Vector2.DOWN],
	Projectile.Lane.HEAD_RIGHT: [Vector2.DOWN],
}

@export_group("Dodge Feel")
## How far the BODY (sprite only) nudges: x = sideways, y = up/down. Pure
## presentation — the hurtbox stays home and the LANE_ANSWERS rule decides dodges,
## so this is a look, not a reach. Keep it small enough to read as a flinch.
@export var dodge_distance := Vector2(50.0, 40.0)
## Seconds to dash out (0.08 = 5 frames). Lower = snappier. Out + hang + return
## together are the ACTIVE WINDOW — dodge while a shot arrives and you've dodged it.
@export var dodge_out_time := 0.08
## Seconds you hang at the far position. THIS IS THE FORGIVENESS KNOB — the heart
## of the active window. Raise it if the game feels unfair.
@export var dodge_hang_time := 0.16
## Seconds to snap back home (0.10 = 6 frames).
@export var dodge_return_time := 0.10
## Easing curve on the way out. QUINT/EXPO = explosive. LINEAR = robotic. This IS "snappy".
@export var dodge_out_trans: Tween.TransitionType = Tween.TRANS_QUINT
## Which end of the out-curve is fast. EASE_OUT = all speed up front, then settle.
@export var dodge_out_ease: Tween.EaseType = Tween.EASE_OUT
## Easing curve on the way back. CUBIC/SINE feel softer than QUINT.
@export var dodge_return_trans: Tween.TransitionType = Tween.TRANS_CUBIC
## Which end of the return-curve is fast. EASE_IN_OUT = soft start and soft landing.
@export var dodge_return_ease: Tween.EaseType = Tween.EASE_IN_OUT

@export_group("Parry")
## Seconds after pressing parry during which attacks are deflected (0.15 = 9 frames).
## See docs/04 §3 — 150ms is "tight but fair"; go wider if playtesters keep missing.
@export var parry_window := 0.15
## Total seconds locked in the parry animation. The gap between this and parry_window
## is your punishment for whiffing — you can't dodge during it.
@export var parry_recovery := 0.35
## Stamina handed back on a successful parry. High = parrying is the skilled way to keep moving.
@export var parry_stamina_refund := 30.0

@export_group("Stamina")
@export var max_stamina := 100.0
## Cost per dodge. max_stamina / this = how many dodges you get on an empty tank.
@export var dodge_stamina_cost := 25.0
## Stamina regained per second.
@export var stamina_regen := 22.0
## Seconds after spending before regen restarts (stops dodge-spam from regenerating through the cost).
@export var stamina_regen_delay := 0.5

@export_group("Health")
@export var max_hp := 3
## Seconds of invincibility after a hit. Prevents one cluster from killing you outright.
@export var iframe_time := 0.9
## Seconds to slide back home after being hit.
@export var hit_recover_time := 0.18
## Easing curve on the slide home after a hit. SINE = limp; BACK = a stagger.
@export var hit_recover_trans: Tween.TransitionType = Tween.TRANS_SINE

@export_group("Input")
## A press this many seconds too early still counts. Leniency — see docs/04 §4.
@export var input_buffer := 0.12

var state: State = State.HOME
var hp := 0
var stamina := 0.0
var home_position := Vector2.ZERO

var parry_time := -1.0        # -1 = not parrying. Counts UP while parrying.
var iframe_left := 0.0
var regen_block := 0.0
var buffered := ""            # buffered input action name
var buffer_left := 0.0
var dodge_direction := Vector2.ZERO   # which way the current dodge went (valid while DODGING)
var _tween: Tween
var _sprite_home := Vector2.ZERO      # the sprite's resting local position

@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	home_position = position
	_sprite_home = sprite.position
	hp = max_hp
	stamina = max_stamina
	Events.stamina_changed.emit(stamina, max_stamina)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if state == State.DEAD:
		return
	_read_input()
	_consume_buffer()
	_regen(delta)


## True only during the deflect window at the START of the parry.
func is_parry_active() -> bool:
	return parry_time >= 0.0 and parry_time <= parry_window


## True for the whole parry, including the whiff-recovery lock.
func is_parrying() -> bool:
	return parry_time >= 0.0


# --- timers ---------------------------------------------------------------

func _tick_timers(delta: float) -> void:
	iframe_left = maxf(iframe_left - delta, 0.0)
	regen_block = maxf(regen_block - delta, 0.0)
	buffer_left = maxf(buffer_left - delta, 0.0)
	if parry_time >= 0.0:
		parry_time += delta
		if parry_time >= parry_recovery:
			parry_time = -1.0          # recovery over, free to act again


# --- input ----------------------------------------------------------------

func _read_input() -> void:
	for action in ACTIONS:
		if Input.is_action_just_pressed(action):
			buffered = action
			buffer_left = input_buffer
	if Input.is_action_just_pressed("parry"):
		buffered = "parry"
		buffer_left = input_buffer


func _consume_buffer() -> void:
	if buffered == "" or buffer_left <= 0.0:
		return
	if buffered == "parry":
		if not is_parrying():
			buffered = ""
			_start_parry()
		return
	# A dodge needs: at home, not locked in a parry, and enough stamina.
	if state != State.HOME or is_parrying():
		return
	if stamina < dodge_stamina_cost:
		buffered = ""
		Events.dodge_failed.emit()
		return
	var direction: Vector2 = ACTIONS[buffered]
	buffered = ""
	_start_dodge(direction)


# --- dodge ----------------------------------------------------------------

func _start_dodge(direction: Vector2) -> void:
	state = State.DODGING
	dodge_direction = direction
	_spend_stamina(dodge_stamina_cost)

	# Only the SPRITE moves — the collider stays home so every shot still reaches
	# _resolve(), where the LANE_ANSWERS rule (not geometry) decides the outcome.
	# The whole nudge is these four lines: out, hang, back, done.
	var target := _sprite_home + direction * dodge_distance
	_tween = create_tween()
	_tween.tween_property(sprite, "position", target, dodge_out_time) \
		.set_trans(dodge_out_trans).set_ease(dodge_out_ease)
	_tween.tween_interval(dodge_hang_time)
	_tween.tween_property(sprite, "position", _sprite_home, dodge_return_time) \
		.set_trans(dodge_return_trans).set_ease(dodge_return_ease)
	_tween.tween_callback(func() -> void: state = State.HOME)

	Events.dodged.emit(direction)
	_on_dodge_start(direction)


func _start_parry() -> void:
	parry_time = 0.0
	_on_parry_start()


# --- taking hits ----------------------------------------------------------

func _on_area_entered(area: Area2D) -> void:
	if area is Projectile:
		_resolve(area as Projectile)


## The ONLY place contact is decided, in strict order:
##   parried  →  dodged (right direction, right time)  →  i-frames  →  hit.
## "Right direction" means dodge_direction is in LANE_ANSWERS for the shot's lane.
func _resolve(projectile: Projectile) -> void:
	if state == State.DEAD:
		return
	if is_parry_active() and projectile.data.parryable:
		_parry_success(projectile)
		return
	if state == State.DODGING and dodge_direction in LANE_ANSWERS[projectile.lane]:
		_dodge_success(projectile)
		return
	if iframe_left > 0.0:
		return                                  # mercy invincibility
	_take_damage(projectile)


func _parry_success(projectile: Projectile) -> void:
	_gain_stamina(parry_stamina_refund)
	projectile.deflect()
	Events.parried.emit(projectile)
	_on_parry_success(projectile)


func _dodge_success(projectile: Projectile) -> void:
	projectile.ghost()
	Events.projectile_dodged.emit(projectile)
	_on_dodge_success(projectile)


func _take_damage(projectile: Projectile) -> void:
	hp = maxi(hp - projectile.data.damage, 0)
	iframe_left = iframe_time
	projectile.queue_free()

	# Kill the dodge BEFORE anything can return: a live tween's finished-callback
	# would set state back to HOME and resurrect a dead player.
	if _tween and _tween.is_valid():
		_tween.kill()

	Events.player_hit.emit(hp)
	_on_hit(projectile)

	if hp == 0:
		state = State.DEAD
		Events.player_died.emit()
		return

	# Cancel any dodge nudge in progress and slide the sprite home.
	state = State.HIT
	_tween = create_tween()
	_tween.tween_property(sprite, "position", _sprite_home, hit_recover_time) \
		.set_trans(hit_recover_trans).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void: state = State.HOME)


# --- stamina --------------------------------------------------------------

func _spend_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	regen_block = stamina_regen_delay
	Events.stamina_changed.emit(stamina, max_stamina)


func _gain_stamina(amount: float) -> void:
	stamina = minf(stamina + amount, max_stamina)
	Events.stamina_changed.emit(stamina, max_stamina)


func _regen(delta: float) -> void:
	if regen_block > 0.0 or stamina >= max_stamina:
		return
	_gain_stamina(stamina_regen * delta)


# --- FLAIR: your hooks ----------------------------------------------------
# These are called at the right moments and do nothing by default. Squash and
# stretch, afterimages, particles, sound — put it here. Nothing else needs to change.

## FLAIR: a dodge just started, heading in `_direction`.
func _on_dodge_start(_direction: Vector2) -> void:
	pass


## FLAIR: the parry window just opened.
func _on_parry_start() -> void:
	pass


## FLAIR: a parry connected — the loudest moment in the game. Make it feel great.
func _on_parry_success(_projectile: Projectile) -> void:
	pass


## FLAIR: a clean dodge — right direction, right time. The shot is ghosting past.
func _on_dodge_success(_projectile: Projectile) -> void:
	pass


## FLAIR: you just lost a heart.
func _on_hit(_projectile: Projectile) -> void:
	pass
