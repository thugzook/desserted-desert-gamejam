# Patterns Cookbook (v3) — Phase 1 Code

Complete, runnable Phase 1 for **Godot 4.7**, updated for the **v3 dodge model** (timed + lane-matched; see `02-architecture.md` §4). Names match the contract in `02-architecture.md` §12.

> **The shipped code in `dodge-guy-gamejam/scripts/` is authoritative.** This cookbook mirrors it for reading and for future sessions; if the two ever disagree, trust the shipped file and fix the cookbook.

Read `02-architecture.md` first — this is the *how*, that's the *why*.

Contents: [Events](#1-events--the-signal-bus) · [Game](#2-game--run-state--timer) · [Player](#3-player--the-file-youll-tune-most) · [ProjectileData](#4-projectiledata--an-attack-type) · [Projectile](#5-projectile) · [Spawner](#6-spawner--difficulty-is-three-numbers) · [HUD](#7-hud) · [Main](#8-main--start--restart) · [Input map](#9-input-map--project-settings) · [Phase 2 seams](#10-phase-2-seams)

---

## 1. `Events` — the signal bus

`autoload/events.gd`. Register in Project Settings → Globals as **`Events`**.

*Source: the topdown template's `scripts/autoloads/Globals.gd`, stripped to signals only — its player/level lookup helpers solve problems we don't have.*

```gdscript
extends Node
## Global signal bus. Emit here when something game-wide happened; connect here to react.
## Rule: only CROSS-SYSTEM news belongs here. A node talking to its own child calls it directly.

@warning_ignore_start("unused_signal")
signal player_hit(hp_left: int)
signal player_died
signal parried(projectile)
signal dodged(direction: Vector2)
signal projectile_dodged(projectile)                   ## A shot was cleanly dodged (right lane, right time).
signal dodge_failed                                    ## Not enough stamina — cue a UI flash.
signal stamina_changed(current: float, max_value: float)
signal run_started
signal run_ended(time_survived: float)
@warning_ignore_restore("unused_signal")
```

---

## 2. `Game` — run state + timer

`autoload/game.gd`. Register as **`Game`**. In Phase 1 **the timer is the score.**

```gdscript
extends Node
## Owns the run: state, the survival clock, the best time. Nothing else.

enum State { MENU, PLAYING, GAME_OVER }

const SAVE_PATH := "user://save.cfg"

var state: State = State.MENU
var time_survived := 0.0
var best_time := 0.0


func _ready() -> void:
	best_time = _load_best()
	Events.player_died.connect(_on_player_died)


func _process(delta: float) -> void:
	if state == State.PLAYING:
		# In Phase 2, Engine.time_scale makes this clock (and the whole game) run
		# faster — which is exactly what "speed up time for more score" means.
		time_survived += delta


func start_run() -> void:
	time_survived = 0.0
	state = State.PLAYING
	Events.run_started.emit()


func _on_player_died() -> void:
	state = State.GAME_OVER
	if time_survived > best_time:
		best_time = time_survived
		_save_best()
	Events.run_ended.emit(time_survived)


## "83.4" -> "01:23:40" (mm:ss:hundredths), matching docs/UI-mock.jpg.
static func format_time(t: float) -> String:
	var minutes := int(t) / 60
	var seconds := int(t) % 60
	var hundredths := int(t * 100.0) % 100
	return "%02d:%02d:%02d" % [minutes, seconds, hundredths]


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("run", "best_time", best_time)
	config.save(SAVE_PATH)


func _load_best() -> float:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 0.0  # first run: no file yet
	return config.get_value("run", "best_time", 0.0)
```

---

## 3. `Player` — the file you'll tune most

`scripts/player.gd`. Every number is an Inspector field; the doc comment says which way to move it.

```gdscript
class_name Player
extends Area2D
## The player. Dodges by physically moving out of the way, parries with a timed
## window that works even mid-dodge, spends stamina to do it.
##
## v3: a dodge is a TIMED WINDOW with a DIRECTION RULE. Press the right direction
## for the incoming lane while it arrives → the shot is neutralized (ghosts
## through you). The body's nudge is pure presentation — the collider never moves.
## The rulebook is LANE_ANSWERS below: one table, edit freely.
##
## TUNE: everything in the @export groups below. 60 physics ticks/sec, so
## frames / 60 = seconds. (5 frames = 0.08s, 9 frames = 0.15s, 12 frames = 0.20s)

enum State { HOME, DODGING, HIT, DEAD }

@export_group("Dodge Feel")
## How far the BODY (sprite only) nudges: x = sideways, y = up/down. Pure
## presentation — the hurtbox stays home and LANE_ANSWERS decides dodges, so
## this is a look, not a reach. Keep it small enough to read as a flinch.
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
## Easing curve on the way back. CUBIC/SINE feel softer than QUINT.
@export var dodge_return_trans: Tween.TransitionType = Tween.TRANS_CUBIC
## Where the dash-out spends its speed. EASE_OUT = fast off the mark, settles into the hang.
@export var dodge_out_ease: Tween.EaseType = Tween.EASE_OUT
## Where the return spends its speed. EASE_IN_OUT = a soft launch and a soft landing.
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
## Easing curve on that slide home. SINE reads as "staggered"; LINEAR reads as "yanked".
@export var hit_recover_trans: Tween.TransitionType = Tween.TRANS_SINE

@export_group("Input")
## A press this many seconds too early still counts. Leniency — see docs/04 §4.
@export var input_buffer := 0.12

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


# --- timers ---------------------------------------------------------------

func _tick_timers(delta: float) -> void:
	iframe_left = maxf(iframe_left - delta, 0.0)
	regen_block = maxf(regen_block - delta, 0.0)
	buffer_left = maxf(buffer_left - delta, 0.0)
	if parry_time >= 0.0:
		parry_time += delta
		if parry_time >= parry_recovery:
			parry_time = -1.0          # recovery over, free to act again


## True only during the deflect window at the START of the parry.
func is_parry_active() -> bool:
	return parry_time >= 0.0 and parry_time <= parry_window

## True for the whole parry, including the whiff-recovery lock.
func is_parrying() -> bool:
	return parry_time >= 0.0


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
		_resolve(area)


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
	Events.player_hit.emit(hp)
	_on_hit(projectile)

	# Kill the dodge tween FIRST — its callback would resurrect a dead player.
	if _tween and _tween.is_valid():
		_tween.kill()

	if hp == 0:
		state = State.DEAD
		Events.player_died.emit()
		return

	# The dodge nudge is cancelled; slide the sprite home from wherever it was.
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


# --- your hooks -----------------------------------------------------------
# These are called at the right moments and do nothing by default. Squash and
# stretch, afterimages, particles, sound — put it here. Nothing else needs to
# change. Grep the project for "## FLAIR:" to find all five.

## FLAIR: fires the instant a dodge starts, with the direction you dodged.
func _on_dodge_start(_direction: Vector2) -> void:
	pass

## FLAIR: a clean dodge — right direction, right time. The shot is ghosting past.
func _on_dodge_success(_projectile: Projectile) -> void:
	pass

## FLAIR: fires when parry is pressed — before you know if it lands. Wind-up cue.
func _on_parry_start() -> void:
	pass

## FLAIR: fires only on a successful deflect. The power-fantasy moment.
func _on_parry_success(_projectile: Projectile) -> void:
	pass

## FLAIR: fires on every hit taken, including the fatal one.
func _on_hit(_projectile: Projectile) -> void:
	pass
```

**Why `parry_time` isn't a state:** it never touches `state`, so pressing parry mid-dodge just works — the spec's airborne-parry case needed no code at all.

---

## 4. `ProjectileData` — an attack type

`scripts/projectile_data.gd`. **One `.tres` per attack type; no code per attack.**

```gdscript
class_name ProjectileData
extends Resource
## One attack type. Create via FileSystem → right-click resources/attacks/ →
## Create New → Resource → ProjectileData, then fill these in.

@export var display_name := "Attack"
## Pixels per second once it launches. 300 = readable, 700 = scary.
@export var speed := 420.0
## Seconds it sits still and visible before launching. This is the player's
## reaction budget — see docs/04 §1. Do not go below ~0.4.
@export var telegraph_time := 0.7
@export var damage := 1
## Can the parry window deflect it? Set false for attacks that must be dodged.
@export var parryable := true
## How hard a parry sends it back — its speed is multiplied by this on deflect.
## Higher = more power fantasy. 1.0 = it just turns around.
@export var deflect_speed_multiplier := 2.0
## How visible a successfully-DODGED shot stays as it coasts through you.
## 0.25 = faint ghost. 0 = it disappears the instant you dodge it.
@export var ghost_alpha := 0.25
## FLAIR: how the player tells this attack from the others, at a glance.
@export var color := Color(0.95, 0.85, 0.6)
@export var size := Vector2(56.0, 18.0)

@export_group("Telegraph Flash")
## Seconds per half-blink while telegraphing. Lower = more frantic.
@export var pulse_rate := 0.12
## How faint the blink goes. Lower = a harder, more alarming strobe.
@export var pulse_min_alpha := 0.35
```

**Ship three placeholders** in `resources/attacks/` (a fast small one, a slow fat one, an unparryable one) so the game runs on first launch. Delete and replace them — that's your design work.

---

## 5. `Projectile`

`scripts/projectile.gd` on `projectile.tscn` (`Area2D` + `ColorRect` named `Sprite` + `CollisionShape2D`).

```gdscript
class_name Projectile
extends Area2D
## Telegraph in place, then fly at where the player was. Configured entirely by a ProjectileData.

## Which direction this shot attacks from — the player's LANE_ANSWERS table maps
## each lane to the dodge direction that beats it.
enum Lane { ABOVE, LEFT, RIGHT, HEAD_LEFT, HEAD_RIGHT }

var data: ProjectileData
var lane: Lane = Lane.ABOVE
var direction := Vector2.ZERO
var telegraph_left := 0.0
var deflected := false
var dodged := false
var despawn_radius := 1500.0                     # overwritten by the Spawner in setup()

var _pulse: Tween

@onready var sprite: ColorRect = $Sprite
@onready var shape: CollisionShape2D = $CollisionShape2D


## Called by the Spawner BEFORE add_child, so _ready() has everything it needs.
func setup(attack: ProjectileData, in_lane: Lane, from: Vector2, toward: Vector2, despawn: float) -> void:
	data = attack
	lane = in_lane
	position = from
	direction = (toward - from).normalized()
	telegraph_left = attack.telegraph_time
	despawn_radius = despawn


func _ready() -> void:
	sprite.color = data.color
	sprite.size = data.size
	sprite.position = -data.size * 0.5
	# A shape saved in the .tscn is SHARED between every instance of it — same
	# hazard as the .tres note under deflect(). Resizing one would resize them
	# all, so each projectile gets its own RectangleShape2D.
	shape.shape = RectangleShape2D.new()
	(shape.shape as RectangleShape2D).size = data.size
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
			# Launch: stop flashing. Kill the loop first or it keeps writing alpha.
			if _pulse and _pulse.is_valid():
				_pulse.kill()
			sprite.modulate.a = 1.0
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
```

> `data.duplicate()` matters: `.tres` resources are **shared between every instance** that loads them. Mutating `data.speed` directly would permanently speed up every future copy of that attack.

---

## 6. `Spawner` — difficulty is four numbers

`scripts/spawner.gd`.

```gdscript
class_name Spawner
extends Node2D
## Picks attacks and throws them at the player. Difficulty = interval ramp + max_alive.

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
## TUNE: the deck of directions (see Projectile.Lane — the dodge that beats each
## lane lives in player.gd's LANE_ANSWERS). Duplicate an entry to make that lane
## more common (two ABOVEs = overheads twice as likely). Remove one to retire it.
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
## How far past the screen a missed attack flies before it deletes itself.
## Must stay comfortably above spawn_radius or attacks vanish on arrival.
@export var despawn_radius := 1500.0

var _next_in := 0.0


func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING or attacks.is_empty():
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
```

Anchoring to `player.home_position` keeps every lane a fixed, learnable approach. Under v3 the lane geometry is the *presentation* of the question; the answer key is `LANE_ANSWERS` in `player.gd` — sidestep the overheads, jump the body shots, duck the head shots.

---

## 7. `HUD`

`scripts/hud.gd` on a `CanvasLayer`. Timer + hearts + the Deadlock-style stamina arc from the mock.

```gdscript
extends CanvasLayer
## Timer, multiplier, hearts, stamina arc, game-over panel. Listens to Events —
## never reaches across the scene tree with $"../..".

## Assigned in main.tscn. Only used to read max_hp — the HUD never drives the player.
@export var player: Player

@onready var time_label: Label = $TimeLabel
@onready var multiplier_label: Label = $MultiplierLabel
@onready var hearts_label: Label = $HeartsLabel
@onready var stamina_arc: Control = $StaminaArc
@onready var game_over: Panel = $GameOverPanel
@onready var result_label: Label = $GameOverPanel/ResultLabel


func _ready() -> void:
	game_over.visible = false
	# Draw exactly max_hp hearts — raising max_hp in the Inspector must not need a code edit.
	hearts_label.text = "♥".repeat(player.max_hp)
	# Phase 1 the multiplier is fixed at x1.0; the mock shows it beside the timer,
	# so it ships now and Phase 2's multiplier just writes to this label.
	multiplier_label.text = "x1.0"
	Events.player_hit.connect(func(hp: int) -> void: hearts_label.text = "♥".repeat(hp))
	Events.stamina_changed.connect(_on_stamina_changed)
	Events.dodge_failed.connect(_on_dodge_failed)
	Events.run_ended.connect(_on_run_ended)


func _process(_delta: float) -> void:
	if Game.state == Game.State.PLAYING:
		time_label.text = Game.format_time(Game.time_survived)


func _on_stamina_changed(current: float, max_value: float) -> void:
	stamina_arc.set_meta("fill", current / max_value)
	stamina_arc.queue_redraw()


## An empty tank silently eats the input otherwise — flash the arc so the player
## knows WHY nothing happened. FLAIR: a shake or a buzz would read even better.
func _on_dodge_failed() -> void:
	var flash := create_tween()
	stamina_arc.modulate = Color(1.0, 0.3, 0.3)
	flash.tween_property(stamina_arc, "modulate", Color.WHITE, 0.25)


func _on_run_ended(time_survived: float) -> void:
	game_over.visible = true
	result_label.text = "TIME  %s\nBEST  %s" % [
		Game.format_time(time_survived), Game.format_time(Game.best_time)
	]
```

`scripts/stamina_arc.gd` on the `StaminaArc` Control — **a FLAIR file, kept deliberately crude:**

```gdscript
extends Control
## FLAIR: segmented arc around the player, Deadlock-style (see docs/UI-mock.jpg).
## Currently plain pips — colors, gaps, glow, and a drain animation are yours.

@export var segments := 8
@export var radius := 42.0
@export var thickness := 5.0
@export var arc_degrees := 140.0


func _draw() -> void:
	var fill: float = get_meta("fill", 1.0)
	var step := deg_to_rad(arc_degrees) / float(segments)
	var start := deg_to_rad(-90.0 - arc_degrees * 0.5)
	for i in segments:
		var lit := (float(i) / float(segments)) < fill
		var color := Color(1, 1, 1, 0.9) if lit else Color(1, 1, 1, 0.15)
		draw_arc(Vector2.ZERO, radius, start + i * step,
			start + (i + 1) * step - 0.06, 8, color, thickness)
```

---

## 8. `Main` — start + restart

`scripts/main.gd`.

```gdscript
extends Node2D
## Starts the run and handles restart. That's all it does.

func _ready() -> void:
	Game.start_run()


func _unhandled_input(event: InputEvent) -> void:
	if Game.state == Game.State.GAME_OVER and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
```

**Restart is one line.** `reload_current_scene()` resets the whole scene; the `Game` and `Events` autoloads survive so `best_time` persists. *(Pattern from the platformer's `killzone.gd` / `level_1.gd`.)* Don't build a reset system.

---

## 9. Input map — project settings

Generated into `project.godot`. Every action gets a WASD-ish key **and** an arrow key:

| Action | Keys |
|---|---|
| `dodge_left` | A, Left |
| `dodge_right` | D, Right |
| `dodge_up` | Space, Up |
| `dodge_down` | S, Down |
| `parry` | J |
| `restart` | Enter, R |

---

## 10. Phase 2 seams

Left open on purpose — none of these require touching Phase 1 structure:

| Phase 2 feature | Where it plugs in |
|---|---|
| Timer multiplier | `Engine.time_scale` in `Game`. Projectiles already move by `speed * delta` and the clock already accumulates `delta`, so one property speeds up the game *and* the score rate together. |
| Upgrades | An `UpgradeData` Resource that writes to the player's `@export` vars at runtime (they're plain vars, not consts, precisely for this). |
| Juice | Hitstop, screenshake, and hit-flash go in a `juice.gd` on Main listening to `Events`. Hitstop uses `Engine.time_scale` too — with the multiplier live, save and restore the current scale rather than assuming `1.0`, and pass `ignore_time_scale = true` as the 4th arg of `get_tree().create_timer()` or the freeze stretches. |
| Torch / light | `PointLight2D` on the player + `CanvasModulate` on Main. |
| Near-miss scoring **(stretch idea — not requested; needs user sign-off, since the spec says score = timer only)** | A second, slightly larger Area2D on the player ("grazebox") that fires when a projectile passes close without hitting. |

**Free assets when you get there:** [sfxr](https://sfxr.me) for retro SFX in seconds, [Kenney](https://kenney.nl/assets) for CC0 art and audio.
