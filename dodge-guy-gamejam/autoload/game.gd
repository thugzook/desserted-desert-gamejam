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


## "83.4" -> "01:23:40" (mm:ss:hundredths), matching docs/UI-mock.jpg.
static func format_time(t: float) -> String:
	@warning_ignore("integer_division")  # whole minutes is exactly what we want
	var minutes := int(t) / 60
	var seconds := int(t) % 60
	var hundredths := int(t * 100.0) % 100
	return "%02d:%02d:%02d" % [minutes, seconds, hundredths]


func _on_player_died() -> void:
	state = State.GAME_OVER
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
