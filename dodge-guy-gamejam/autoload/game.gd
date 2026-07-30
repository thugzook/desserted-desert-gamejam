extends Node
## Owns the run: state, the survival clock, the best time, and the SPEED MULTIPLIER
## that every pattern clear raises.

enum State { MENU, PLAYING, GAME_OVER }

const SAVE_PATH := "user://save.cfg"

var state: State = State.MENU
var time_survived := 0.0
var best_time := 0.0

## The whole "everything is 25% faster" knob, driven by PatternSpawner on every
## pattern clear. The setter is the entire implementation: Engine.time_scale
## scales the delta handed to every _process/_physics_process (so the clock,
## every Tween, the torch animation, projectile travel and the spawner's own song
## clock all speed up together), and playback_speed_scale does the same for all
## audio. Same factor on both = the pattern stays locked to the music.
var speed := 1.0:
	set(value):
		speed = value
		Engine.time_scale = value
		AudioServer.playback_speed_scale = value

## Set once the 5-measure tutorial has been cleared, so restarts skip it. Lives
## here (not in save.cfg) on purpose: autoloads survive reload_current_scene(),
## so this persists across deaths but resets when the game is quit.
var tutorial_cleared := false

var _speed_tween: Tween


func _ready() -> void:
	best_time = _load_best()
	Events.player_died.connect(_on_player_died)


func _process(delta: float) -> void:
	if state == State.PLAYING:
		# In Phase 2, Engine.time_scale makes this clock (and the whole game) run
		# faster — which is exactly what "speed up time for more score" means.
		time_survived += delta
	# Re-assert rather than trust. A stream starting a fresh playback (the music
	# reaching its end and looping) drops the audio rate back to 1.0, which
	# desyncs the song from the chart for the rest of the run. Writing a float
	# each frame costs nothing; a desynced chart costs the whole mechanic.
	if not is_equal_approx(AudioServer.playback_speed_scale, speed):
		AudioServer.playback_speed_scale = speed


func start_run() -> void:
	time_survived = 0.0
	# Engine.time_scale and playback_speed_scale are ENGINE globals — they survive
	# get_tree().reload_current_scene(), so without this a restart would inherit
	# the speed the last run died at.
	_reset_speed()
	state = State.PLAYING
	Events.run_started.emit()


## Ease into a new speed multiplier. Tweened rather than snapped so a boost reads
## as the world winding up instead of a jump cut.
func apply_speed(target: float, tween_time: float) -> void:
	if _speed_tween and _speed_tween.is_valid():
		_speed_tween.kill()
	Events.speed_changed.emit(target)
	if tween_time <= 0.0:
		speed = target
		return
	# ignore_time_scale is load-bearing: this tween WRITES Engine.time_scale, so
	# without it the tween accelerates itself as it runs and finishes early.
	_speed_tween = create_tween()
	_speed_tween.set_ignore_time_scale(true)
	_speed_tween.tween_property(self, "speed", target, tween_time)


## "83.4" -> "01:23:40" (mm:ss:hundredths), matching docs/UI-mock.jpg.
static func format_time(t: float) -> String:
	@warning_ignore("integer_division")  # whole minutes is exactly what we want
	var minutes := int(t) / 60
	var seconds := int(t) % 60
	var hundredths := int(t * 100.0) % 100
	return "%02d:%02d:%02d" % [minutes, seconds, hundredths]


func _reset_speed() -> void:
	if _speed_tween and _speed_tween.is_valid():
		_speed_tween.kill()
	speed = 1.0


func _on_player_died() -> void:
	state = State.GAME_OVER
	_reset_speed()   # don't leave the game-over screen (and its music) stuck at 2x
	if time_survived > best_time:
		best_time = time_survived
		_save_best()
	Events.run_ended.emit(time_survived)


func _save_best() -> void:
	var config := ConfigFile.new()
	config.set_value("run", "best_time", best_time)
	config.save(SAVE_PATH)


func _load_best() -> float:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 0.0  # first run: no file yet
	return config.get_value("run", "best_time", 0.0)
