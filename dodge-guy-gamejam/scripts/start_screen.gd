extends Control
## Title card: black screen, the control list, and a blinking "press any key".
##
## Shown ONCE at launch. The game's own restart is reload_current_scene() on
## main.tscn, so dying never comes back here — you drop straight into a new run.
##
## WHERE TO EDIT WHAT:
##   Titles, hint, prompt — click the Label in THIS SCENE and type. This script
##     deliberately never touches their text, size, or colour, so what you set in
##     the editor is what ships. Add as many Labels to Layout as you want; they
##     pick up the pixel font automatically.
##   The control rows — `control_rows` below, because that grid is generated at
##     runtime and so has no Labels to click.
##
## Silkscreen is drawn on an 8px grid: keep every font size a MULTIPLE OF 8
## (8, 16, 24, 32...) or glyph edges land between pixels and the text goes mushy.

## The scene "any key" loads.
@export_file("*.tscn") var game_scene := "res://scenes/main.tscn"
## Drop a pixel .ttf here and every Label on this screen switches to it.
## Empty = Godot's default font, which is NOT pixel-art.
@export var pixel_font: Font

@export_group("Controls List")
## One row per entry, written "KEY|WHAT IT DOES". Reorder, add, or delete freely —
## the grid rebuilds itself from this list, so nothing else needs touching.
@export var control_rows: Array[String] = [
	"A|MOVE LEFT",
	"D|MOVE RIGHT",
	"W  or  SPACE|JUMP",
	"S|DUCK",
]
## Multiple of 8. Only the generated rows — every other Label owns its own size.
@export var body_font_size := 16
## The key column. Brighter than the description so the input reads first.
@export var key_color := Color(1.0, 0.85, 0.35)
@export var action_color := Color(0.78, 0.80, 0.86)

@export_group("Prompt Blink")
## Seconds for one full fade-out-and-back of the prompt. 0 = no blink.
@export var blink_period := 1.1
## How faint the prompt goes at the bottom of the blink.
@export_range(0.0, 1.0) var blink_min_alpha := 0.15

var _started := false

@onready var controls: GridContainer = $Center/Layout/Controls
@onready var hint: Label = $Center/Layout/Hint
@onready var prompt: Label = $Center/Layout/Prompt


func _ready() -> void:
	if pixel_font != null:
		# One Theme on the root restyles every Label beneath it — including the
		# rows built below, and any Label you add to the scene later.
		var pixel_theme := Theme.new()
		pixel_theme.set_font("font", "Label", pixel_font)
		theme = pixel_theme
	# Clear the hint's text in the scene and the gap closes up too.
	hint.visible = not hint.text.strip_edges().is_empty()
	_build_controls()
	_start_blink()


## Any key, pad button, or click starts the run. Mouse counts on purpose: on web
## it doubles as the gesture browsers require before audio is allowed to play.
func _unhandled_input(event: InputEvent) -> void:
	if _started or not event.is_pressed():
		return
	if event is InputEventKey and (event as InputEventKey).is_echo():
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		# The scene change is deferred to the end of the frame, so without this
		# latch a fast double-press queues it twice.
		_started = true
		get_tree().change_scene_to_file(game_scene)


# --- private ----------------------------------------------------------------

## Fill the two-column grid from `control_rows`. A GridContainer (rather than one
## padded multi-line Label) so the columns still line up before a monospace
## pixel font is dropped in.
func _build_controls() -> void:
	for child in controls.get_children():
		child.queue_free()
	for row in control_rows:
		var parts := row.split("|", false, 1)
		if parts.is_empty():
			continue
		var key := parts[0].strip_edges()
		var action := parts[1].strip_edges() if parts.size() > 1 else ""
		controls.add_child(_make_cell(key, HORIZONTAL_ALIGNMENT_RIGHT, key_color))
		controls.add_child(_make_cell(action, HORIZONTAL_ALIGNMENT_LEFT, action_color))


func _make_cell(text: String, align: HorizontalAlignment, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", body_font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _start_blink() -> void:
	if blink_period <= 0.0:
		return
	var half := blink_period * 0.5
	var blink := create_tween().set_loops()
	blink.tween_property(prompt, "modulate:a", blink_min_alpha, half)
	blink.tween_property(prompt, "modulate:a", 1.0, half)
