class_name Player
extends Area2D
## The player. A dodge is a TIMED WINDOW with a DIRECTION RULE: press the right
## direction for the incoming lane while it arrives and the projectile is
## neutralized (it ghosts through you). By default only the SPRITE nudges — the
## hurtbox stays home, so every shot still reaches _resolve() and LANE_ANSWERS is
## the sole judge (user decision 2026-07-27, reverting the moving-hurtbox trial:
## a 25px nudge on a 190px hurtbox cleared nothing and only silenced feedback).
## Flip dodge_moves_hurtbox to make dodges spatial instead. Dodges are
## interruptible: a new dodge input redirects mid-animation; only parry recovery
## locks you out.
## STAMINA IS DISABLED — every stamina line is commented, grep "STAMINA DISABLED".
##
## The dodge rulebook is LANE_ANSWERS below — one table, edit freely.
##
## TUNE: everything in the @export groups below. 60 physics ticks/sec, so
## frames / 60 = seconds. (5 frames = 0.08s, 9 frames = 0.15s, 12 frames = 0.20s)

enum State { READY, DODGING, HIT, DEAD }

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
## OFF (default): only the sprite nudges, the hurtbox never moves, and LANE_ANSWERS
## alone decides every shot — dodging is a timed window plus the rule table.
## ON: the whole Area2D moves, so geometry decides too and a dodge can physically
## clear (or walk into) a lane. Only turn this on if dodge_distance is large
## relative to the hurtbox — at 190px tall, a 20px nudge clears nothing and just
## severs contact so successful dodges give no feedback.
@export var dodge_moves_hurtbox := false
## ON: starting a dodge COMMITS you — no new dodge input until it finishes.
## Landing a dodge or a parry releases the lock the instant it connects, so clean
## play still keeps tempo; only a whiff actually costs you the animation. This is
## what stops mashing from being a strategy. OFF: dodges are freely interruptible.
@export var dodge_commits := true
## How far a dodge moves: x = sideways, y = up/down. With dodge_moves_hurtbox OFF
## this is pure presentation — a flinch, not a reach — so keep it small enough to
## read as body language. With it ON, this is your actual escape distance.
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
## Placeholder feedback until there's real parry art: the color art flashes to
## on a parry press, fading back to normal. Swap this system out once you have
## a dedicated parry sprite frame.
@export var parry_flash_color := Color.WHITE
## Seconds for the flash to fade back to normal (0.15 = 9 frames).
@export var parry_flash_time := 0.15

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
## Seconds for ONE on/off blink while invincible. Lower = more frantic strobe.
## 0 turns the flash off. Keep it well under iframe_time or you get one slow pulse.
@export var iframe_flash_period := 0.12
## How faint the sprite goes at the bottom of each i-frame blink. 0 = fully
## invisible (hard strobe), 1 = no visible flash at all.
@export_range(0.0, 1.0) var iframe_flash_alpha := 0.25
## Seconds to slide back home after being hit. 0 = snap home instantly.
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
var _dodge_scored := false            # this dodge landed something — the commit lock is released
var _tween: Tween
var _iframe_tween: Tween      # the blink. Its own tween so it can outlive the slide home.
var _parry_flash_tween: Tween
var _sprite_home := Vector2.ZERO      # the sprite's resting local position

@onready var sprite: ColorRect = $Sprite
## The drawn body. Rides on the sprite box, so it inherits the dodge nudge and
## the i-frame blink. Owns one image per direction — see player_art.gd.
@onready var art: PlayerArt = $Sprite/Art
## The blob shadow. Deliberately NOT a child of the sprite box — it has to stay
## on the ground while the body leaves it. Fed by _process below.
@onready var shadow: PlayerShadow = $Shadow
## Sounds are named for WHEN they play, not what they contain — swap the stream
## or set volume on the node in the Inspector.
@onready var dodge_sound: AudioStreamPlayer = $DodgeSound
@onready var hit_sound: AudioStreamPlayer = $HitSound


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
	#sprite.modulate = Color.CORAL


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if state == State.DEAD:
		return
	_read_input()
	_consume_buffer()
	# STAMINA DISABLED (2026-07-26): no recharge while dodges are free.
	#_regen(delta)


## Read in _process, not _physics_process, because the dodge tween runs on the
## idle step — sampling it here keeps the shadow exactly in sync with the drawn
## body instead of a frame behind it. Measured off the SPRITE because that's the
## node a dodge nudges (with dodge_moves_hurtbox ON the sprite never moves, so
## the shadow just rides along with the body and won't react to height).
func _process(_delta: float) -> void:
	shadow.set_lift(_sprite_home.y - sprite.position.y, sprite.position.x - _sprite_home.x)


## True only during the deflect window at the START of the parry.
func is_parry_active() -> bool:
	return parry_time >= 0.0 and parry_time <= parry_window


## True only if user has parry on cooldown because they missed their parry
func is_parry_on_cooldown() -> bool:
	return parry_time > parry_window
 
func is_parry_blocked() -> bool:
	return is_parry_active() or is_parry_on_cooldown()


# --- timers ---------------------------------------------------------------

func _tick_timers(delta: float) -> void:
	var was_invincible := iframe_left > 0.0
	iframe_left = maxf(iframe_left - delta, 0.0)
	if was_invincible and iframe_left <= 0.0:
		_end_iframe_flash()   # i-frames just expired — stop blinking, go solid
	regen_block = maxf(regen_block - delta, 0.0)
	buffer_left = maxf(buffer_left - delta, 0.0)
	if parry_time >= 0.0:
		parry_time += delta
		if parry_time >= parry_recovery:
			_end_parry()         # recovery over, free to act again


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
	# A dodge needs: input not committed to a dodge already, and not locked in a
	# parry. Note this gate is BELOW the parry branch on purpose — parrying mid-dodge
	# must stay free no matter what the dodge lock says.
	if not _can_dodge_now() or is_parry_blocked():
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
	_dodge_scored = false   # a fresh dodge is unproven, so it commits you again
	# STAMINA DISABLED (2026-07-26): dodges are free.
	#_spend_stamina(dodge_stamina_cost)

	# By default only the sprite travels, so the collider stays put and every shot
	# still reaches _resolve() — where the LANE_ANSWERS rule, not geometry, decides.
	# The whole nudge is these four lines: out, hang, back, done.
	_recenter_idle_node()
	var mover := _dodge_mover()
	var origin := _dodge_origin()
	var target := origin + direction * (dodge_distance / 2 if dodge_direction == Vector2.DOWN else dodge_distance)
	_tween = create_tween()
	_tween.tween_property(mover, "position", target, dodge_out_time) \
		.set_trans(dodge_out_trans).set_ease(dodge_out_ease)
	_tween.tween_interval(dodge_hang_time)
	_tween.tween_property(mover, "position", origin, dodge_return_time) \
		.set_trans(dodge_return_trans).set_ease(dodge_return_ease)
	_tween.tween_callback(_end_dodge)

	art.show_dodge(direction)   # pose only — the rule table still decides the hit
	Events.dodged.emit(direction)
	_on_dodge_start(direction)


## The ONE place a dodge closes. Only the tween callback above may call this —
## the active window is out + hang + return, and landing a shot must not cut it
## short (see the class docstring).
func _end_dodge() -> void:
	state = State.READY
	art.show_idle()


## Can a dodge START this instant? READY always. Mid-dodge only if dodges don't
## commit, or this one already landed a dodge or a parry. HIT and DEAD never accept
## one. This is the whole lock — "land anything, keep moving; whiff and you're stuck."
func _can_dodge_now() -> bool:
	if state == State.READY:
		return true
	if state != State.DODGING:
		return false
	return not dodge_commits or _dodge_scored


## Which node a dodge displaces, and where that node rests. One pair of accessors
## so flipping dodge_moves_hurtbox retargets the dodge, the hit-slide, and the
## interrupt logic all at once.
func _dodge_mover() -> Node:
	if dodge_moves_hurtbox:
		return self
	return sprite


func _dodge_origin() -> Vector2:
	return home_position if dodge_moves_hurtbox else _sprite_home


## Snap whichever node ISN'T dodging back to its rest spot. Only matters when
## dodge_moves_hurtbox is toggled in the Inspector mid-run — without this the
## previously-displaced node would stay stranded off-centre forever.
func _recenter_idle_node() -> void:
	if dodge_moves_hurtbox:
		sprite.position = _sprite_home
	else:
		position = home_position


func _start_parry() -> void:
	parry_time = 0.0
	_flash_parry()

func _end_parry() -> void:
	parry_time = -1



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
	# Same rule as a landed dodge: succeed at anything and you keep moving. If this
	# parry happened mid-dodge, it releases that dodge's commit lock too.
	_dodge_scored = true

	# reset parry window because successful parry
	_end_parry()


func _dodge_success(projectile: Projectile) -> void:
	projectile.ghost()
	Events.projectile_dodged.emit(projectile)
	_dodge_scored = true   # you landed it — dodge again whenever you like
	dodge_sound.play()     # bark! play() restarts it, so rapid dodges each bark
	# Deliberately does NOT end the dodge: the active window is out + hang + return,
	# and only the tween's callback closes it. Clearing state here used to make the
	# FIRST shot you dodged correctly the last one you were safe from, so anything
	# else arriving in the same window landed as a hit.


func _take_damage(projectile: Projectile) -> void:
	hp = maxi(hp - projectile.data.damage, 0)
	iframe_left = iframe_time
	projectile.queue_free()

	# Kill the dodge BEFORE anything can return: a live tween's finished-callback
	# would set state back to HOME and resurrect a dead player.
	if _tween and _tween.is_valid():
		_tween.kill()
	art.show_idle()   # killing the tween skips _end_dodge, so drop the pose here

	Events.player_hit.emit(hp)
	_on_hit(projectile)

	if hp == 0:
		state = State.DEAD
		Events.player_died.emit()
		return

	# Getting hit puts you back to start, whatever you were in the middle of: the
	# dodge is cancelled (tween killed above), the body slides home, and the blink
	# says "you're invincible right now" for as long as iframe_left lasts.
	_start_iframe_flash()
	_recenter_idle_node()   # the node the dodge DIDN'T move can't be left stranded
	state = State.HIT
	_tween = create_tween()
	_tween.tween_property(_dodge_mover(), "position", _dodge_origin(), hit_recover_time) \
		.set_trans(hit_recover_trans).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void: state = State.READY)


# --- parry flash ------------------------------------------------------------

## Blink art white on a parry press, fading back to normal. self_modulate only
## affects THIS node (never cascades to children), so it can't leak onto — or
## get overwritten by — the sprite box's own modulate (used for the i-frame
## blink) or any future child art gets.
func _flash_parry() -> void:
	if _parry_flash_tween and _parry_flash_tween.is_valid():
		_parry_flash_tween.kill()
	art.self_modulate = parry_flash_color
	_parry_flash_tween = create_tween()
	_parry_flash_tween.tween_property(art, "self_modulate", Color.WHITE, parry_flash_time)


# --- i-frame flash --------------------------------------------------------

## Blink the sprite for as long as you're invincible. Only ALPHA is animated, never
## the colour — art's self_modulate owns the hue, so parrying mid-blink still reads normally.
func _start_iframe_flash() -> void:
	if _iframe_tween and _iframe_tween.is_valid():
		_iframe_tween.kill()
	if iframe_flash_period <= 0.0:
		return
	var half := iframe_flash_period * 0.5
	# Looped forever on purpose: _tick_timers kills it the frame i-frames expire, so
	# the blink always matches iframe_time even if you tune iframe_time at runtime.
	_iframe_tween = create_tween().set_loops()
	_iframe_tween.tween_property(sprite, "modulate:a", iframe_flash_alpha, half)
	_iframe_tween.tween_property(sprite, "modulate:a", 1.0, half)


func _end_iframe_flash() -> void:
	if _iframe_tween and _iframe_tween.is_valid():
		_iframe_tween.kill()
	sprite.modulate.a = 1.0   # never leave the player stuck half-transparent


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
	hit_sound.play()
