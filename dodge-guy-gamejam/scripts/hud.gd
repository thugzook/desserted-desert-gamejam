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

@export_group("Boost Feedback")
## How much the multiplier SNAPS to on a boost, on top of its resting size.
## 2.2 = more than double. This is the whole "look at me, it went up" spike.
@export var boost_pop_scale := 2.2
## Seconds for the pop to settle. ELASTIC needs ~1s+ for the wobble to read.
@export var boost_pop_time := 1.2
## The settle curve. ELASTIC = rubbery, wobbles a few times (the "crazy" one).
## BACK = one clean overshoot. CUBIC = no overshoot at all.
@export var boost_pop_trans: Tween.TransitionType = Tween.TRANS_ELASTIC
## PERMANENT growth per +1.00 of multiplier — at 0.35, reaching x2.00 leaves the
## label 35% bigger than it started, so the number literally grows as you climb.
## 0 = every pop settles back to the original size.
@export var multiplier_growth := 0.35
## Ceiling on the resting size, so a long run can't push the label off the HUD.
@export var max_multiplier_scale := 2.0
## Colour the multiplier flashes on a boost, fading back to normal as it settles.
@export var boost_flash_color := Color(1.0, 0.85, 0.3)

var _arc_flash: Tween
var _boost_pop: Tween

@onready var time_label: Label = $TimeLabel
@onready var multiplier_label: Label = $MultiplierLabel
@onready var hearts_label: Label = $HeartsLabel
@onready var stamina_arc: Control = $StaminaArc
@onready var game_over: Panel = $GameOverPanel
@onready var result_label: Label = $GameOverPanel/ResultLabel


func _ready() -> void:
	game_over.visible = false
	# Scale about the label's centre, not its top-left corner, or the pop lurches
	# down-right instead of blooming in place.
	multiplier_label.pivot_offset = multiplier_label.size * 0.5
	_refresh_hearts(_max_hp())
	Events.run_started.connect(_on_run_started)
	Events.player_hit.connect(_refresh_hearts)
	Events.run_ended.connect(_on_run_ended)
	Events.speed_changed.connect(_on_speed_changed)
	# STAMINA DISABLED (2026-07-26): arc hidden, listeners off. Uncomment this
	# block (and the ones in player.gd) to bring the mechanic back.
	stamina_arc.visible = false
	#Events.dodge_failed.connect(_on_dodge_failed)
	#Events.stamina_changed.connect(_on_stamina_changed)
	## The Player is _ready() before the HUD is, so its opening stamina_changed
	## already went out. Seed the arc by hand instead of waiting for the first dodge.
	#if player != null:
	#	_on_stamina_changed(player.stamina, player.max_stamina, 0.0)


func _process(_delta: float) -> void:
	if Game.state == Game.State.PLAYING:
		time_label.text = Game.format_time(Game.time_survived)
		# Polled rather than pushed so the number counts up THROUGH the boost
		# tween instead of snapping to the final value.
		multiplier_label.text = "x%.2f" % Game.speed


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


## A pattern was cleared and everything is winding up to `multiplier`. The label's
## NUMBER animates itself (see _process); this is the punctuation that makes you
## look at it — a hard scale spike that wobbles down to a new, slightly bigger
## resting size, plus a colour flash.
func _on_speed_changed(multiplier: float) -> void:
	var rest := minf(1.0 + (multiplier - 1.0) * multiplier_growth, max_multiplier_scale)
	if _boost_pop and _boost_pop.is_valid():
		_boost_pop.kill()
	multiplier_label.scale = Vector2.ONE * rest * boost_pop_scale
	multiplier_label.modulate = boost_flash_color
	# ignore_time_scale: the boost is RAISING Engine.time_scale at this exact
	# moment, so without it this animation gets faster the bigger the boost —
	# the one thing that must not happen to the effect announcing the boost.
	_boost_pop = create_tween().set_parallel()
	_boost_pop.set_ignore_time_scale(true)
	_boost_pop.tween_property(multiplier_label, "scale", Vector2.ONE * rest, boost_pop_time) \
		.set_trans(boost_pop_trans).set_ease(Tween.EASE_OUT)
	_boost_pop.tween_property(multiplier_label, "modulate", Color.WHITE, boost_pop_time)


## A fresh run — the multiplier is back to x1.00, so the label must be too.
func _on_run_started() -> void:
	_refresh_hearts(_max_hp())
	if _boost_pop and _boost_pop.is_valid():
		_boost_pop.kill()
	multiplier_label.scale = Vector2.ONE
	multiplier_label.modulate = Color.WHITE


func _on_run_ended(time_survived: float) -> void:
	game_over.visible = true
	result_label.text = "TIME  %s\nBEST  %s" % [
		Game.format_time(time_survived), Game.format_time(Game.best_time)
	]
