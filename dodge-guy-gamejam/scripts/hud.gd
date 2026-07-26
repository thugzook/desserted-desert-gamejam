extends CanvasLayer
## Timer, hearts, stamina arc, game-over panel. Listens to Events — never reaches
## across the scene tree with $"../..".

## Wired in main.tscn. Only read for max_hp — everything else arrives via Events.
@export var player: Player

@export_group("Feedback")
## Colour the stamina arc flashes when a dodge is refused for lack of stamina.
@export var arc_flash_color := Color(1.0, 0.3, 0.3)
## Seconds the flash takes to fade back to normal. Longer = harder to miss.
@export var arc_flash_time := 0.15

var _arc_flash: Tween

@onready var time_label: Label = $TimeLabel
@onready var multiplier_label: Label = $MultiplierLabel
@onready var hearts_label: Label = $HeartsLabel
@onready var stamina_arc: Control = $StaminaArc
@onready var game_over: Panel = $GameOverPanel
@onready var result_label: Label = $GameOverPanel/ResultLabel


func _ready() -> void:
	game_over.visible = false
	# Phase 2 drives this from the timer multiplier; it is deliberately static here.
	multiplier_label.text = "x1.0"
	_refresh_hearts(_max_hp())
	Events.run_started.connect(func() -> void: _refresh_hearts(_max_hp()))
	Events.player_hit.connect(_refresh_hearts)
	Events.dodge_failed.connect(_on_dodge_failed)
	Events.stamina_changed.connect(_on_stamina_changed)
	Events.run_ended.connect(_on_run_ended)
	# The Player is _ready() before the HUD is, so its opening stamina_changed
	# already went out. Seed the arc by hand instead of waiting for the first dodge.
	if player != null:
		_on_stamina_changed(player.stamina, player.max_stamina, 0.0)


func _process(_delta: float) -> void:
	if Game.state == Game.State.PLAYING:
		time_label.text = Game.format_time(Game.time_survived)


func _max_hp() -> int:
	return player.max_hp if player != null else 3


func _refresh_hearts(hp: int) -> void:
	hearts_label.text = "♥".repeat(maxi(hp, 0))


func _on_stamina_changed(current: int, max_value: int, partial: float) -> void:
	# The arc's pip count follows max_stamina, so an upgrade that grants more bars
	# grows the arc without touching the HUD.
	stamina_arc.set_meta("segments", max_value)
	stamina_arc.set_meta("filled", current)
	stamina_arc.set_meta("partial", partial)
	stamina_arc.queue_redraw()


## Out of stamina. Without this the dodge just silently doesn't happen.
func _on_dodge_failed() -> void:
	if _arc_flash and _arc_flash.is_valid():
		_arc_flash.kill()
	stamina_arc.modulate = arc_flash_color
	_arc_flash = create_tween()
	_arc_flash.tween_property(stamina_arc, "modulate", Color.WHITE, arc_flash_time)


func _on_run_ended(time_survived: float) -> void:
	game_over.visible = true
	result_label.text = "TIME  %s\nBEST  %s" % [
		Game.format_time(time_survived), Game.format_time(Game.best_time)
	]
