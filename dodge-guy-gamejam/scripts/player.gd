class_name Player
extends Area2D
## The player. A dodge is a TIMED WINDOW with a DIRECTION RULE: press the right
## direction for the incoming lane while it arrives and the projectile is
## neutralized (it ghosts through you). The WHOLE body moves — hurtbox included
## (user decision 2026-07-26) — so ducking really slips under head shots, and
## dodging INTO a shot's path means parry or pay. Dodges are interruptible: a new
## dodge input redirects mid-animation; only parry recovery locks you out.
## STAMINA IS DISABLED — every stamina line is commented, grep "STAMINA DISABLED".
##
## The dodge rulebook is LANE_ANSWERS below — one table, edit freely.
##
## TUNE: everything in the @export groups below. 60 physics ticks/sec, so
## frames / 60 = seconds. (5 frames = 0.08s, 9 frames = 0.15s, 12 frames = 0.20s)

enum State { READY, DODGING, HIT, DEAD }

const PARRY_STATE := {
	"idle": Color.CORAL,
	"parry_active": Color.BLUE,
	"parry_whiffed": Color.BLACK,
	"parry_blocked": Color.RED,
	"parry_success": Color.WHITE
}

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
	Projectile.Lane.ABOVE_CENTER: [Vector2.LEFT, Vector2.RIGHT],
	Projectile.Lane.ABOVE_LEFT: [Vector2.RIGHT],
	Projectile.Lane.ABOVE_RIGHT: [Vector2.LEFT],
	Projectile.Lane.FEET_LEFT: [Vector2.UP],
	Projectile.Lane.FEET_RIGHT: [Vector2.UP],
	Projectile.Lane.HEAD_LEFT: [Vector2.DOWN],
	Projectile.Lane.HEAD_RIGHT: [Vector2.DOWN],
}

@export_group("Dodge Feel")
## How far the WHOLE body (sprite + hurtbox) moves: x = sideways, y = up/down.
## This is a real reach now — raise y and ducks/jumps physically clear head/feet
## shots; raise x and sidesteps can clear overheads. Small values keep dodging
## mostly rule-based (LANE_ANSWERS), big values make it spatial.
@export var dodge_distance := Vector2(25, 20)
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
@export var parry_window := 0.05
## Total seconds locked in the parry animation. The gap between this and parry_window
## is your punishment for whiffing — you can't dodge during it.
@export var parry_recovery := 0.35
## Bars handed back on a successful parry. High = parrying is the skilled way to keep moving.
@export var parry_stamina_refund := 1

@export_group("Stamina")
## How many dodges a full tank holds. Each bar is exactly one dodge, so a Phase 2
## upgrade that adds 2 here adds 2 visible pips AND 2 dodges. Raise = more forgiving.
@export var max_stamina := 4
## Bars spent per dodge. Keep this at 1 — it's what makes "+1 max = +1 dodge" true
## for the player. Raising it breaks that read.
@export var dodge_stamina_cost := 0
## Seconds to recharge ONE bar. Lower = dodge more often.
@export var stamina_recharge_time := 1.2
## Seconds after spending before recharging resumes (stops dodge-spam from
## recharging through the cost).
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

var state: State = State.READY
var hp := 0
var stamina := 0                ## whole bars available right now
var _recharge_progress := 0.0   ## 0..1 toward the next bar
var home_position := Vector2.ZERO
var player_size := Vector2.ZERO

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
	player_size = sprite.size
	_sprite_home = sprite.position
	hp = max_hp
	# STAMINA DISABLED (2026-07-26): uncomment these and the other "STAMINA
	# DISABLED" blocks (player.gd + hud.gd) to bring the whole mechanic back.
	#stamina = max_stamina
	#_emit_stamina()
	area_entered.connect(_on_area_entered)
	sprite.modulate = Color.CORAL


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if state == State.DEAD:
		return
	_read_input()
	_consume_buffer()
	# STAMINA DISABLED (2026-07-26): no recharge while dodges are free.
	#_regen(delta)


## True only during the deflect window at the START of the parry.
func is_parry_active() -> bool:
	return parry_time >= 0.0 and parry_time <= parry_window


## True only if user has parry on cooldown because they missed their parry
func is_parry_on_cooldown() -> bool:
	if (parry_time > parry_window):
		#sprite.modulate = PLAYER_STATE["parry_whiffed"]
		return true
	return false
 
func is_parry_blocked() -> bool:
	return is_parry_active() or is_parry_on_cooldown()


# --- timers ---------------------------------------------------------------

func _tick_timers(delta: float) -> void:
	iframe_left = maxf(iframe_left - delta, 0.0)
	regen_block = maxf(regen_block - delta, 0.0)
	buffer_left = maxf(buffer_left - delta, 0.0)
	if parry_time >= 0.0:
		parry_time += delta
		if parry_time >= parry_recovery:
			_end_parry()         # recovery over, free to act again
		elif is_parry_on_cooldown():
			sprite.modulate = PARRY_STATE["parry_whiffed"]


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
		if not is_parry_blocked():
			buffered = ""
			_start_parry()
		return
	# A dodge needs: not mid-hit-stagger, not locked in a parry. A dodge already in
	# progress CAN be interrupted by a new one (user decision 2026-07-26) — parry
	# recovery is the only real lockout.
	if (state != State.READY and state != State.DODGING) or is_parry_blocked():
		return
	# STAMINA DISABLED (2026-07-26): dodges are free.
	#if stamina < dodge_stamina_cost:
	#	buffered = ""
	#	Events.dodge_failed.emit()
	#	return
	var direction: Vector2 = ACTIONS[buffered]
	buffered = ""
	_start_dodge(direction)

# --- dodge ----------------------------------------------------------------

func _start_dodge(direction: Vector2) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()   # interrupting an earlier dodge — redirect from wherever we are
	state = State.DODGING
	dodge_direction = direction
	# STAMINA DISABLED (2026-07-26): dodges are free.
	#_spend_stamina(dodge_stamina_cost)

	# The WHOLE node moves — sprite AND hurtbox together (user decision 2026-07-26):
	# ducking really slips under head shots, and jumping INTO a shot's path means
	# parry or pay. A right-answer dodge that stays in contact is still forgiven by
	# LANE_ANSWERS in _resolve(). Lanes keep aiming at home_position, which no
	# longer follows us — that's the whole point.
	var target := home_position + direction * dodge_distance
	_tween = create_tween()
	_tween.tween_property(self, "position", target, dodge_out_time) \
		.set_trans(dodge_out_trans).set_ease(dodge_out_ease)
	_tween.tween_interval(dodge_hang_time)
	_tween.tween_property(self, "position", home_position, dodge_return_time) \
		.set_trans(dodge_return_trans).set_ease(dodge_return_ease)
	_tween.tween_callback(func() -> void: state = State.READY)

	Events.dodged.emit(direction)
	_on_dodge_start(direction)


func _start_parry() -> void:
	parry_time = 0.0
	sprite.modulate = PARRY_STATE["parry_active"]
	
func _end_parry() -> void:
	parry_time = -1
	sprite.modulate = PARRY_STATE["idle"]
	


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
	# STAMINA DISABLED (2026-07-26): no refund while dodges are free.
	#_gain_stamina(parry_stamina_refund)
	projectile.deflect()
	Events.parried.emit(projectile)
	sprite.modulate = PARRY_STATE["parry_success"]
	
	# reset parry window because successful parry
	_end_parry()


func _dodge_success(projectile: Projectile) -> void:
	projectile.ghost()
	Events.projectile_dodged.emit(projectile)
	state = State.READY # reset 


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

	# Cancel any dodge in progress and slide the whole body (hurtbox included) home.
	state = State.HIT
	_tween = create_tween()
	_tween.tween_property(self, "position", home_position, hit_recover_time) \
		.set_trans(hit_recover_trans).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void: state = State.READY)


# --- stamina --------------------------------------------------------------

func _spend_stamina(bars: int) -> void:
	stamina = maxi(stamina - bars, 0)
	regen_block = stamina_regen_delay
	_emit_stamina()


func _gain_stamina(bars: int) -> void:
	stamina = mini(stamina + bars, max_stamina)
	_emit_stamina()


## Runs every physics tick, so _recharge_progress creeps up 60x/sec and the HUD's
## partial pip grows smoothly. Progress deliberately SURVIVES spending — you don't
## lose a nearly-finished bar by dodging.
func _regen(delta: float) -> void:
	if regen_block > 0.0 or stamina >= max_stamina:
		return
	_recharge_progress += delta / stamina_recharge_time
	while _recharge_progress >= 1.0 and stamina < max_stamina:
		_recharge_progress -= 1.0
		stamina += 1
	if stamina >= max_stamina:
		_recharge_progress = 0.0   # full tank shows no half-lit pip
	_emit_stamina()


func _emit_stamina() -> void:
	Events.stamina_changed.emit(stamina, max_stamina, _recharge_progress)


# --- FLAIR: your hooks ----------------------------------------------------
# These are called at the right moments and do nothing by default. Squash and
# stretch, afterimages, particles, sound — put it here. Nothing else needs to change.

## FLAIR: a dodge just started, heading in `_direction`.
func _on_dodge_start(_direction: Vector2) -> void:
	pass




## FLAIR: you just lost a heart.
func _on_hit(_projectile: Projectile) -> void:
	pass
