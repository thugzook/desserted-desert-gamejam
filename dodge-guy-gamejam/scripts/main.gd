extends Node2D
## Starts the run and handles restart. That's all it does.


func _ready() -> void:
	Game.start_run()


func _unhandled_input(event: InputEvent) -> void:
	# Restart is one line: reloading the scene rebuilds everything, while the
	# Events and Game autoloads survive so best_time persists.
	if Game.state == Game.State.GAME_OVER and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
