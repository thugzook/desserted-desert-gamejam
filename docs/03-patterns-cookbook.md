# Patterns Cookbook

Copy-paste-ready GDScript for every system in the game, written for **Godot 4.7**. Each pattern says where it came from, why it's shaped this way, and what to tweak. Names match the contract in `02-architecture.md` §7 exactly.

Contents:
1. [Player state machine](#1-player-state-machine-playergd)
2. [Input buffer](#2-input-buffer)
3. [Attack resolution (hurtbox idea)](#3-attack-resolution)
4. [Health (inline vs component)](#4-health)
5. [Signal bus](#5-signal-bus-autoloadeventsgd)
6. [Attack projectile](#6-attack-projectile-attackgd)
7. [Attack data + spawner](#7-attackdata-wavedata-and-the-spawner)
8. [Game manager, HUD, restart](#8-game-manager-hud-game-overrestart)
9. [Juice pack](#9-juice-pack-hitstop-screenshake-flash)
10. [Audio](#10-audio)

---

## 1. Player state machine (`player.gd`)

**Source:** replaces the topdown template's node-based `StateMachine` (see doc 02 §6 for why). Structure inspired by the platformer's "everything visible in one file" style.

The complete player. Patterns 2–4 are embedded in it and explained separately after.

```gdscript
class_name Player
extends Area2D
## The player: a fixed sprite that ducks, jumps, slides, and parries incoming attacks.
## All timing is tunable in the Inspector — see the Action Durations group.

enum PlayerState { IDLE, DUCK, JUMP, SLIDE_LEFT, SLIDE_RIGHT, PARRY, HIT, DEAD }

@export_group("Action Durations")
@export var duck_duration := 0.4     ## Seconds the duck lasts (also the dodge window for high attacks).
@export var jump_duration := 0.5     ## Seconds the jump lasts.
@export var slide_duration := 0.4    ## Seconds a slide lasts.
@export var parry_duration := 0.3    ## Total parry animation time (committed, can't act).
@export var parry_active_window := 0.15  ## Only the FIRST part of the parry deflects (see doc 04 §3).
@export var hit_stun := 0.5          ## Seconds of stun + invincibility after being hit.
@export_group("Feel")
@export var input_buffer_window := 0.12  ## Early inputs within this window still count (doc 04 §4).
@export_group("Health")
@export var max_hp := 3

# Maps input action names -> the state they trigger.
const ACTIONS := {
	"duck": PlayerState.DUCK,
	"jump": PlayerState.JUMP,
	"slide_left": PlayerState.SLIDE_LEFT,
	"slide_right": PlayerState.SLIDE_RIGHT,
	"parry": PlayerState.PARRY,
}

# Which player state dodges which attack type (states double as dodges).
const STATE_BEATS_DODGE := {
	PlayerState.DUCK: AttackData.DodgeType.DUCK,
	PlayerState.JUMP: AttackData.DodgeType.JUMP,
	PlayerState.SLIDE_LEFT: AttackData.DodgeType.SLIDE_LEFT,
	PlayerState.SLIDE_RIGHT: AttackData.DodgeType.SLIDE_RIGHT,
	PlayerState.PARRY: AttackData.DodgeType.PARRY,
}

var state: PlayerState = PlayerState.IDLE
var state_time := 0.0        # seconds spent in the current state
var hp := 0

# --- input buffer (pattern 2) ---
var buffered_action := ""
var time_since_buffered := 999.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	hp = max_hp
	area_entered.connect(_on_area_entered)
	_enter_state(PlayerState.IDLE)


func _physics_process(delta: float) -> void:
	state_time += delta
	time_since_buffered += delta
	if state == PlayerState.DEAD:
		return
	_capture_input()

	match state:
		PlayerState.IDLE:
			_try_consume_buffer()
		PlayerState.DUCK:
			if state_time >= duck_duration: _enter_state(PlayerState.IDLE)
		PlayerState.JUMP:
			if state_time >= jump_duration: _enter_state(PlayerState.IDLE)
		PlayerState.SLIDE_LEFT, PlayerState.SLIDE_RIGHT:
			if state_time >= slide_duration: _enter_state(PlayerState.IDLE)
		PlayerState.PARRY:
			if state_time >= parry_duration: _enter_state(PlayerState.IDLE)
		PlayerState.HIT:
			if state_time >= hit_stun: _enter_state(PlayerState.IDLE)


func _enter_state(new_state: PlayerState) -> void:
	state = new_state
	state_time = 0.0
	# Animation names in the SpriteFrames must match these exactly (lowercase).
	match state:
		PlayerState.IDLE: sprite.play("idle")
		PlayerState.DUCK: sprite.play("duck")
		PlayerState.JUMP: sprite.play("jump")
		PlayerState.SLIDE_LEFT: sprite.play("slide_left")
		PlayerState.SLIDE_RIGHT: sprite.play("slide_right")
		PlayerState.PARRY: sprite.play("parry")
		PlayerState.HIT: sprite.play("hit")
		PlayerState.DEAD: sprite.play("dead")


# --- input (patterns 2) ---

func _capture_input() -> void:
	for action in ACTIONS:
		if Input.is_action_just_pressed(action):
			buffered_action = action
			time_since_buffered = 0.0


func _try_consume_buffer() -> void:
	if buffered_action != "" and time_since_buffered <= input_buffer_window:
		var next: PlayerState = ACTIONS[buffered_action]
		buffered_action = ""
		_enter_state(next)


# --- attack resolution (pattern 3) ---

func _on_area_entered(area: Area2D) -> void:
	if area is Attack:
		resolve_attack(area)


func resolve_attack(attack: Attack) -> void:
	if state == PlayerState.DEAD:
		return
	var data: AttackData = attack.data
	var result := "hit"

	if STATE_BEATS_DODGE.get(state) == data.dodge_type:
		result = "dodged"
	# Parry is special: only its ACTIVE window counts, and it can also beat parryable attacks.
	if state == PlayerState.PARRY and state_time <= parry_active_window \
			and (data.parryable or data.dodge_type == AttackData.DodgeType.PARRY):
		result = "parried"

	if result == "hit":
		if state == PlayerState.HIT:
			return  # i-frames: already stunned, can't be hit again
		_take_damage(data.damage)

	attack.resolve(result)                # tell the projectile so it can react (fly off / vanish)
	Events.attack_resolved.emit(result, data)


# --- health (pattern 4, inline version) ---

func _take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	Events.player_hit.emit(amount)
	if hp == 0:
		_enter_state(PlayerState.DEAD)
		Events.player_died.emit()
	else:
		_enter_state(PlayerState.HIT)
```

**Tweakables:** every duration in the Inspector. Make `parry_active_window` bigger if playtesters miss parries (they will — see doc 04 §3).

---

## 2. Input buffer

**Source:** standard action-game pattern (KidsCanCode's coyote-time recipe uses the same timestamp shape: https://kidscancode.org/godot_recipes/4.x/2d/coyote_time/index.html). Already embedded in `player.gd` above.

**Why:** without it, a player who presses `parry` 50ms before their slide finishes gets *nothing* — the input is dropped and it feels broken. With it, the press is remembered for `input_buffer_window` (0.12s) and fires the instant the player returns to IDLE. This single pattern is most of what people mean by "tight controls."

**The shape** (reusable anywhere): record `time_since_pressed = 0` on press; each tick increment it; the action is "buffered" while `time_since_pressed <= window`; set it huge (999) to consume.

---

## 3. Attack resolution

**Source:** the topdown template's `entities/hurt_box.gd` — its line 23 disables the hurtbox while the entity is jumping (`process_mode = PROCESS_MODE_DISABLED if action == "jump"`). That's the seed idea: *your defensive state changes what can hit you.*

**Our generalization** (in `resolve_attack()` above): instead of toggling collision objects per state, we keep collisions always-on and compare `attack.dodge_type` to the player's state in one readable function. Same outcome, but:

- one place to debug ("why did that hit me?" → read one function),
- no collision-layer bookkeeping across 5 lanes,
- easy to add rules later (fail-soft blocks, combo bonuses) — they're just more lines in the same `if` chain.

**Tie-breaking rule** (doc 04 §4): the checks run *dodge first, hit last*, so a same-frame overlap while entering a dodge resolves in the player's favor.

---

## 4. Health

Two options — **use the inline one** (already in `player.gd`) unless you find yourself wanting HP on something else too.

**Option A — inline (recommended):** the `hp` var + `_take_damage()` in pattern 1. Ten lines, zero indirection.

**Option B — component node**, simplified from the template's `components/health_controller.gd` (dropping its State hooks and PackedScene health bar):

```gdscript
class_name Health
extends Node
## Attach as a child of anything that can take damage. Emits, never decides.

@export var max_hp := 3
@export var recovery_time := 0.5  ## i-frames after each hit.

var hp := 0
var invincible := false

signal hp_changed(new_hp: int)
signal died

func _ready() -> void:
	hp = max_hp

func change_hp(amount: int) -> void:
	if invincible and amount < 0:
		return
	hp = clampi(hp + amount, 0, max_hp)
	hp_changed.emit(hp)
	if amount < 0:
		_start_iframes()
	if hp == 0:
		died.emit()

func _start_iframes() -> void:
	invincible = true
	await get_tree().create_timer(recovery_time).timeout
	invincible = false
```

Note the template's version has a subtle bug worth avoiding: it reuses its `immortal` flag for both "i-frames" and "god mode," so overlapping recoveries can fight. Keeping a separate `invincible` var avoids it.

---

## 5. Signal bus (`autoload/events.gd`)

**Source:** the topdown template's `scripts/autoloads/Globals.gd`, stripped to signals only (its player/level lookup helpers solve problems we don't have).

Complete file:

```gdscript
extends Node
## Global signal bus. Emit here when something game-wide happened; connect here to react.
## Rule: only CROSS-SYSTEM news belongs here ("call down, signal up" — see CLAUDE.md).

@warning_ignore_start("unused_signal")
signal attack_spawned(attack)                    ## An attack entered the screen.
signal attack_resolved(result: String, attack_data)  ## "dodged" | "parried" | "hit"
signal player_hit(damage: int)
signal player_died
signal score_changed(new_score: int)
signal game_state_changed(new_state)
@warning_ignore_restore("unused_signal")
```

(The `@warning_ignore` lines silence "unused signal" warnings — the bus itself never emits them; other scripts do, e.g. `Events.player_died.emit()`.)

Register: Project Settings → Globals → path `res://autoload/events.gd`, name `Events`.

---

## 6. Attack projectile (`attack.gd`)

**Source:** original, using the Tween API (verified against https://docs.godotengine.org/en/stable/classes/class_tween.html). Telegraph philosophy from doc 04 §2.

One generic scene (`attack.tscn`: `Area2D` + `AnimatedSprite2D` + `CollisionShape2D`), configured entirely by an `AttackData`:

```gdscript
class_name Attack
extends Area2D
## A single incoming attack. Spawned by AttackSpawner, configured by an AttackData.
## Life: telegraph (wind-up in place) -> travel (tween to the player) -> resolved by Player.

var data: AttackData
var resolved := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sfx: AudioStreamPlayer = $AudioStreamPlayer


func setup(attack_data: AttackData, target: Vector2) -> void:
	data = attack_data
	# Called by the spawner BEFORE add_child, so _ready can use it.
	set_meta("target", target)


func _ready() -> void:
	if data.sprite_frames:
		sprite.sprite_frames = data.sprite_frames
		sprite.play("default")
	if data.telegraph_sfx:
		sfx.stream = data.telegraph_sfx
		sfx.play()  # the sound IS the telegraph — starts immediately (doc 04 §2)

	var target: Vector2 = get_meta("target")
	var tween := create_tween()
	# Telegraph: pulse in place so the player can read it.
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), data.telegraph_time * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "scale", Vector2.ONE, data.telegraph_time * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Travel: constant speed at the player (readable — no easing surprises, doc 04 §2).
	tween.tween_property(self, "position", target, data.travel_time) \
		.set_trans(Tween.TRANS_LINEAR)
	# Fly past and clean up if nothing resolved us (shouldn't happen, but be safe).
	tween.tween_property(self, "position", target + (target - position).normalized() * 400, 0.4)
	tween.tween_callback(queue_free)


func resolve(result: String) -> void:
	if resolved:
		return
	resolved = true
	monitoring = false  # stop detecting; we're done
	match result:
		"parried":
			# Knocked away: reverse direction fast, spin, vanish.
			var tw := create_tween()
			tw.tween_property(self, "position", position + Vector2(300, -200), 0.3) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(self, "rotation", 6.0, 0.3)
			tw.tween_callback(queue_free)
		"hit":
			queue_free()  # impact feedback is the player/camera's job
		"dodged":
			pass  # keep flying past on the original tween — near-misses feel great
```

**Tweakables:** everything lives in the `AttackData` resource, not here. The pulse-scale telegraph is placeholder juice — replace with a wind-up animation when art exists.

---

## 7. AttackData, WaveData, and the spawner

**Source:** Resource pattern from the template's `items/data_item.gd`; typed resource arrays confirmed for 4.x (https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_exports.html).

`scripts/attack_data.gd` and `scripts/wave_data.gd` are specified in doc 02 §5 — copy them from there verbatim.

**Creating an attack in the editor (no code):** FileSystem dock → right-click `resources/attacks/` → Create New → Resource → type `AttackData` → name it (`donut_high.tres`) → fill the Inspector fields. Same for `WaveData` (drag attack `.tres` files into its `beats` array).

`scripts/attack_spawner.gd`:

```gdscript
class_name AttackSpawner
extends Node2D
## Plays WaveData patterns: spawns each attack, waits the gap, rests between waves.

@export var waves: Array[WaveData]   ## Drag wave .tres files here, in play order.
@export var attack_scene: PackedScene
@export var player: Player           ## Drag the Player node here.
@export var spawn_distance := 400.0  ## How far from the player attacks appear.

signal all_waves_finished

# Where each attack type spawns, relative to the player. High attacks (you DUCK
# under them) come at head height; low attacks (you JUMP over) at the feet, etc.
const SPAWN_OFFSETS := {
	AttackData.DodgeType.DUCK: Vector2(1.0, -0.15),
	AttackData.DodgeType.JUMP: Vector2(1.0, 0.25),
	AttackData.DodgeType.SLIDE_LEFT: Vector2(1.0, 0.0),
	AttackData.DodgeType.SLIDE_RIGHT: Vector2(-1.0, 0.0),
	AttackData.DodgeType.PARRY: Vector2(1.0, -0.05),
}


func play() -> void:
	for wave in waves:
		for attack_data in wave.beats:
			_spawn(attack_data)
			await get_tree().create_timer(wave.gap).timeout
		await get_tree().create_timer(wave.rest_after).timeout
	all_waves_finished.emit()


func _spawn(attack_data: AttackData) -> void:
	var attack: Attack = attack_scene.instantiate()
	var offset: Vector2 = SPAWN_OFFSETS[attack_data.dodge_type] * spawn_distance
	attack.position = player.position + offset
	# Aim slightly past the player so the projectile passes through, not stops on, them.
	attack.setup(attack_data, player.position)
	add_child(attack)
	Events.attack_spawned.emit(attack)
```

**Tweakables:** wave order and contents are pure `.tres` editing — this is where "designing the game" happens all week. `spawn_distance` + each attack's `travel_time` together set the speed feel.

---

## 8. Game manager, HUD, game over/restart

**Source:** the platformer's `gamemanager.gd` (score + label), `killzone.gd` (restart flow), `level_1.gd` (panel + button), upgraded with signals instead of `$"../CanvasLayer/scorelabel"` path reaching — paths break the moment you rearrange the scene; signals don't.

`autoload/game_manager.gd`:

```gdscript
extends Node
## Owns game state, score, and the persisted high score. Nothing else.

enum GameState { MENU, PLAYING, GAME_OVER }

const SAVE_PATH := "user://highscore.cfg"
const POINTS := {"dodged": 10, "parried": 25, "hit": 0}

var state: GameState = GameState.MENU
var score := 0
var high_score := 0


func _ready() -> void:
	high_score = _load_high_score()
	Events.attack_resolved.connect(_on_attack_resolved)
	Events.player_died.connect(_on_player_died)


func start_game() -> void:
	score = 0
	_set_state(GameState.PLAYING)
	Events.score_changed.emit(score)


func _on_attack_resolved(result: String, _attack_data) -> void:
	score += POINTS.get(result, 0)
	Events.score_changed.emit(score)


func _on_player_died() -> void:
	if score > high_score:
		high_score = score
		_save_high_score()
	_set_state(GameState.GAME_OVER)


func _set_state(new_state: GameState) -> void:
	state = new_state
	Events.game_state_changed.emit(state)


func _save_high_score() -> void:
	var config := ConfigFile.new()
	config.set_value("scores", "high_score", high_score)
	config.save(SAVE_PATH)


func _load_high_score() -> int:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 0  # first run: no file yet
	return config.get_value("scores", "high_score", 0)
```

`scripts/hud.gd` (on the HUD CanvasLayer):

```gdscript
extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var hearts_label: Label = $HeartsLabel
@onready var game_over_panel: Panel = $GameOverPanel


func _ready() -> void:
	game_over_panel.visible = false
	Events.score_changed.connect(func(s): score_label.text = "SCORE: %d" % s)
	Events.player_hit.connect(_on_player_hit)
	Events.game_state_changed.connect(_on_game_state_changed)


func _on_player_hit(_damage: int) -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	hearts_label.text = "♥".repeat(player.hp)


func _on_game_state_changed(new_state) -> void:
	game_over_panel.visible = new_state == GameManager.GameState.GAME_OVER


func _on_restart_button_pressed() -> void:  # connect the button's `pressed` signal to this
	get_tree().reload_current_scene()
	GameManager.start_game()
```

**Restart philosophy** (from the platformer): `get_tree().reload_current_scene()` is the entire "reset the game" implementation. Autoloads (GameManager, Events) survive the reload; everything in the scene resets for free. Don't build a reset system.

---

## 9. Juice pack (hitstop, screenshake, flash)

**Source:** hitstop from the platformer's `killzone.gd` (`Engine.time_scale = 0.5` on death); screenshake is the community-canonical trauma pattern (https://kidscancode.org/godot_recipes/4.x/2d/screen_shake/index.html); APIs verified for 4.7.

Add all three to a `scripts/juice.gd` on Main, connected to `Events.attack_resolved`:

```gdscript
extends Node
## Feedback effects. Everything here is cosmetic — deleting this file changes no rules.

@export var camera: Camera2D
@export var player_sprite: AnimatedSprite2D


func _ready() -> void:
	Events.attack_resolved.connect(_on_attack_resolved)


func _on_attack_resolved(result: String, _data) -> void:
	match result:
		"parried":
			hitstop(0.12, 0.05)
			shake(0.4)
		"hit":
			hitstop(0.08, 0.1)
			shake(0.7)
			flash(player_sprite)


## Freeze the whole game briefly. GOTCHA: a normal create_timer is ALSO slowed by
## time_scale, so the freeze would last 20x longer than asked. The 4th argument
## (ignore_time_scale = true) makes the timer count real time. Godot 4.7 signature:
## create_timer(time_sec, process_always := true, process_in_physics := false, ignore_time_scale := false)
func hitstop(duration: float, scale: float) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


## Quick decaying shake via camera offset. For the fancier noise-based version see
## the KidsCanCode recipe; this tween version is 6 lines and jam-sufficient.
func shake(strength: float) -> void:
	var tween := create_tween()
	for i in 6:
		var punch := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * 12.0
		tween.tween_property(camera, "offset", punch, 0.03)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)


## White-ish blink on hit. Plain modulate can't reach full white over a sprite's own
## colors — good enough for a jam; a shader does it properly if we ever care.
func flash(sprite: CanvasItem) -> void:
	sprite.modulate = Color(3, 3, 3)   # overbright
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
```

**Order of value** (from "Juice It or Lose It" — https://gamejuice.co.uk/resources/juice-it-or-lose-it): sound > hitstop > shake > particles. Budget half of day 4 for this; it's the highest rating-per-hour work in a jam.

---

## 10. Audio

**Source:** the platformer's setup, kept as-is because it's exactly right for a jam.

- **SFX:** one `AudioStreamPlayer` child per sound, on the node that owns the moment (the attack owns its telegraph sound, the HUD owns the game-over sting). Play with `$AudioStreamPlayer.play()`. Don't build a sound manager.
- **Per-attack telegraph sounds** are gameplay, not polish — they're set in `AttackData.telegraph_sfx` and played by `attack.gd` (pattern 6). Audio reaction time beats visual by ~50ms (doc 04 §2).
- **Music:** an autoload *scene* (like the platformer's `Bgscore`) — an `AudioStreamPlayer` with autoplay on. Because it's an autoload it **survives `reload_current_scene()`**, so the music doesn't hiccup on restart. Register the scene (not script) as an autoload.
- If a sound must finish before deleting a node: `await $AudioStreamPlayer.finished` then `queue_free()` (platformer's `coins.gd` trick) — or just put the player on the HUD instead.

**Free assets:** sfxr/jsfxr (https://sfxr.me) generates retro SFX in seconds; Kenney (https://kenney.nl/assets) for CC0 sounds and art.
