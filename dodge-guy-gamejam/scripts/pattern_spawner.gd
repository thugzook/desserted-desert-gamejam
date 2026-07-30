class_name PatternSpawner
extends Node2D
## Plays authored beat patterns (JSON from tools/pattern-editor.html) in two stages.
##
## A note in the pattern marks when the attack ARRIVES at the player — the moment
## they must dodge or parry — not when it spawns. This node works backwards and
## spawns each shot lead_time() seconds early (telegraph + travel), which is what
## keeps the attacks landing on the beat.
##
## PROGRESSION: the TUTORIAL stage plays the first `tutorial_measures` of the
## tutorial file ONCE, then the MAIN stage loops main_pattern forever. Surviving
## to the end of either one is a "clear": boost sound + `speed_step` added to
## Game.speed, which speeds up literally everything (see game.gd's `speed`).
##
## Coordinate assumption: same as Spawner — this node sits at (0, 0) in main.tscn,
## and all aiming math is shared via Spawner.lane_endpoints().

## Lane string in the JSON meaning "keep the beat, hide the direction" —
## the actual lane is rolled from `lanes` the moment the note spawns.
const ANY_LANE := "ANY"

enum Stage { TUTORIAL, MAIN }

@export var projectile_scene: PackedScene
## TUNE: the one attack type every note uses. One attack = one uniform lead time,
## which keeps "arrives on the beat" easy to reason about. Per-note attacks are a
## later feature, on purpose.
@export var attack: ProjectileData
@export var player: Player

@export_group("Pattern")
## The warm-up, played ONCE at the start of the first run. Author patterns in
## tools/pattern-editor.html, export, drop the .json into res://patterns/.
@export_file("*.json") var tutorial_pattern_path := "res://patterns/test_pattern.json"
## How many measures of the tutorial file to actually use — the rest of the file
## is ignored, so you can trim the warm-up without editing the JSON.
## 0 = no tutorial, drop straight into the main pattern.
@export var tutorial_measures := 5
## The real pattern. Loops forever once the tutorial is done, and every full
## clear of it is a boost.
@export_file("*.json") var main_pattern_path := "res://patterns/main_pattern.json"
## 0 = use the BPM saved in the pattern file. Set above 0 to override — raising
## it speeds the whole song up without editing the pattern.
@export var bpm_override := 0.0
## Beats of silence before measure 1 the first time through. Reaction runway —
## keep it at least ~3 so the very first note still gets its full telegraph.
@export var lead_in_beats := 6
## Beats of silence inserted after EVERY measure (including the last, before the
## loop wraps). The player's breather between phrases. 0 = measures back to back;
## 2 = a half-measure rest in 4/4; 4 = a full silent measure after each one.
@export var rest_beats_between_measures := 4
## TUNE: which lanes an "ANY" (undisclosed direction) note may resolve to.
## Duplicate an entry to weight it, remove one to retire it.
@export var lanes: Array[Projectile.Lane] = [
	Projectile.Lane.ABOVE_LEFT,
	Projectile.Lane.ABOVE_RIGHT,
	Projectile.Lane.ABOVE_CENTER,
	Projectile.Lane.FEET_LEFT,
	Projectile.Lane.FEET_RIGHT,
	Projectile.Lane.HEAD_LEFT,
	Projectile.Lane.HEAD_RIGHT,
]

@export_group("Progression")
## Added to the speed multiplier every time you clear a pattern (the tutorial
## counts). 0.25 = "everything 25% faster" — timer, animations, music, sfx.
@export var speed_step := 0.25
## Seconds to ease into the new speed. 0 = snap instantly. Longer = the world
## audibly winds up rather than jump-cutting.
@export var speed_tween_time := 1.5
## Ceiling on the multiplier. 0 = uncapped, keep escalating forever.
@export var max_speed := 0.0
## Plays on every clear. Leave empty to use assets/sounds/boost.mp3.
@export var boost_sound: AudioStream

@export_group("Call Sound")
## Beats before a note ARRIVES that its call tick plays. With 4 (and a 4-beat
## rest between measures) each phrase is heard as "bum bum bum bum" during the
## rest, then answered by the attacks on those same beats. 0 = no calls.
@export var cue_beats := 5.0
## The tick sound. Leave empty to use the built-in assets/sounds/cue_tick.wav.
@export var cue_sound: AudioStream

@export_group("Placement")
## How far off-screen attacks appear. Also the travel distance, so it's half of
## lead_time() — change it and the spawner re-schedules everything automatically.
@export var spawn_radius := 720.0
## How far a shot travels from the screen centre before it deletes itself.
## Must comfortably exceed spawn_radius or attacks vanish before they arrive.
@export var despawn_radius := 1500.0

var _notes: Array[Dictionary] = []  # sorted by "beats"; "lane" of -1 means ANY
var _loop_beats := 0.0              # length of one full pattern loop, in beats
var _seconds_per_beat := 0.6
var _song_time := 0.0               # seconds since the run started
var _next_note := 0                 # index into _notes of the next unspawned note
var _loop := 0                      # how many times the pattern has wrapped
var _next_cue := 0                  # second cursor over _notes, for the call sounds
var _cue_loop := 0
var _cue_player: AudioStreamPlayer
var _boost_player: AudioStreamPlayer
var _stage: Stage = Stage.MAIN
var _loops_forever := true          # false during the tutorial: it plays once and stops
var _clears := 0                    # full cycles the player has SURVIVED this stage


func _ready() -> void:
	if cue_sound == null:
		cue_sound = load("res://assets/sounds/cue_tick.wav")
	if boost_sound == null:
		boost_sound = load("res://assets/sounds/boost.mp3")
	# Built in code, not the scene, so main.tscn needs no wiring for audio.
	_cue_player = AudioStreamPlayer.new()
	_cue_player.stream = cue_sound
	_cue_player.max_polyphony = 4   # 16th-note calls overlap; let them ring
	add_child(_cue_player)
	_boost_player = AudioStreamPlayer.new()
	_boost_player.stream = boost_sound
	add_child(_boost_player)
	# Game.tutorial_cleared survives reload_current_scene(), so once you've beaten
	# the warm-up you never sit through it again this session.
	if tutorial_measures > 0 and not Game.tutorial_cleared:
		_begin_stage(Stage.TUTORIAL)
	else:
		_begin_stage(Stage.MAIN)


func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING or _notes.is_empty() or player == null:
		return
	_song_time += delta
	# Fire every note whose ARRIVAL falls within lead_time of now. Usually zero or
	# one per frame; the while catches dense 16th clusters after a lag spike.
	# The size guard is what ENDS the tutorial: with _loops_forever off the cursor
	# runs off the end and just stops, so no note past tutorial_measures ever
	# spawns and nothing bleeds into the main pattern.
	while _next_note < _notes.size() and _arrival_seconds(_next_note) <= _song_time + lead_time():
		_spawn(_notes[_next_note])
		_next_note += 1
		if _next_note >= _notes.size() and _loops_forever:  # pattern wraps
			_next_note = 0
			_loop += 1
	# Cleared a full cycle? Checked against ARRIVAL time, not the spawn cursor —
	# that one runs lead_time() ahead, so keying off it would fire the boost while
	# the last few arrows were still in the air.
	if _song_time >= _cycle_end_seconds():
		_on_cycle_cleared()
	# The audio CALL: same walk over the same notes, but cue_beats ahead of each
	# arrival instead of lead_time — the phrase is heard before it must be answered.
	if cue_beats <= 0.0:
		return
	while _next_cue < _notes.size() and _cue_seconds(_next_cue) <= _song_time:
		_cue_player.play()
		print_verbose("PatternSpawner: cue for beat %.2f at t=%.3f" % [
				_notes[_next_cue]["beats"], _song_time])
		_next_cue += 1
		if _next_cue >= _notes.size() and _loops_forever:
			_next_cue = 0
			_cue_loop += 1


## Seconds between a shot spawning and reaching the player: telegraph + travel.
## Every lane travels spawn_radius pixels (see Spawner.lane_endpoints), so one
## number serves all seven.
func lead_time() -> float:
	return attack.telegraph_time + spawn_radius / attack.speed


# --- stages -----------------------------------------------------------------


## Switch to a stage and restart the song clock on its pattern. Resetting
## _song_time means lead_in_beats applies again, which is a deliberate breather:
## it gives the boost moment room to land before the next pattern opens up.
func _begin_stage(stage: Stage) -> void:
	_stage = stage
	_loops_forever = stage == Stage.MAIN
	_song_time = 0.0
	_next_note = 0
	_loop = 0
	_next_cue = 0
	_cue_loop = 0
	_clears = 0
	_notes.clear()
	if stage == Stage.TUTORIAL:
		_load_pattern(tutorial_pattern_path, tutorial_measures)
	else:
		_load_pattern(main_pattern_path, 0)


## Song-seconds at which the current cycle finishes. Once _song_time passes this
## the player has survived the whole pattern (they can't get here dead — see the
## Game.state guard at the top of _physics_process).
func _cycle_end_seconds() -> float:
	return (lead_in_beats + (_clears + 1) * _loop_beats) * _seconds_per_beat


## Survived a full pattern. One rule for every clear, tutorial included: boost
## sound, then everything gets speed_step faster.
func _on_cycle_cleared() -> void:
	_clears += 1
	_boost_player.play()
	var target := Game.speed + speed_step
	if max_speed > 0.0:
		target = minf(target, max_speed)
	Game.apply_speed(target, speed_tween_time)
	print_verbose("PatternSpawner: cleared %s cycle, speed -> %.2f" % [
			Stage.keys()[_stage], target])
	if _stage == Stage.TUTORIAL:
		Game.tutorial_cleared = true
		_begin_stage(Stage.MAIN)


# --- private ---------------------------------------------------------------


## When note `i` of the CURRENT loop arrives at the player, in song seconds.
func _arrival_seconds(i: int) -> float:
	var beats: float = lead_in_beats + _loop * _loop_beats + _notes[i]["beats"]
	return beats * _seconds_per_beat


## When note `i`'s call tick sounds: cue_beats before its arrival.
func _cue_seconds(i: int) -> float:
	var beats: float = lead_in_beats + _cue_loop * _loop_beats + _notes[i]["beats"] - cue_beats
	return beats * _seconds_per_beat


func _spawn(note: Dictionary) -> void:
	var lane: Projectile.Lane
	if int(note["lane"]) == -1:
		lane = lanes.pick_random()  # undisclosed direction: beat kept, lane rolled now
	else:
		lane = int(note["lane"]) as Projectile.Lane
	var endpoints := Spawner.lane_endpoints(lane, player, spawn_radius)
	var projectile: Projectile = projectile_scene.instantiate()
	projectile.setup(attack, lane, endpoints[0], endpoints[1], despawn_radius)
	add_child(projectile)
	# Silent unless the game runs with --verbose: timing audit for beat alignment.
	print_verbose("PatternSpawner: beat %.2f (%s) spawned at t=%.3f, arrives t=%.3f" % [
			note["beats"], Projectile.Lane.keys()[lane], _song_time, _song_time + lead_time()])


## Read and validate a pattern file. Bad notes are logged and skipped — a typo
## in a lane name must never crash a run.
## `max_measures` > 0 uses only that many measures from the front of the file and
## ignores the rest; 0 uses the whole thing.
func _load_pattern(path: String, max_measures: int) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("PatternSpawner: can't read '%s' — no attacks will spawn." % path)
		return
	var data: Variant = JSON.parse_string(text)
	if data == null or not data is Dictionary:
		push_error("PatternSpawner: '%s' isn't valid JSON — no attacks will spawn." % path)
		return

	var bpm := bpm_override if bpm_override > 0.0 else float(data.get("bpm", 100.0))
	_seconds_per_beat = 60.0 / bpm
	# Every measure is stretched by the rest, so notes keep their in-measure
	# timing but each phrase starts rest_beats later than the file says.
	var beats_per_measure := float(data.get("beats_per_measure", 4)) + rest_beats_between_measures
	var steps_per_beat := float(data.get("steps_per_beat", 4))
	var measures := float(data.get("measures", 10))
	if max_measures > 0:
		measures = minf(measures, float(max_measures))
	_loop_beats = measures * beats_per_measure

	for note: Dictionary in data.get("notes", []):
		var measure := float(note.get("measure", 0))
		if max_measures > 0 and measure >= float(max_measures):
			continue   # past the trim point — this note isn't part of this stage
		var lane_name := str(note.get("lane", ""))
		var lane := -1
		if lane_name != ANY_LANE:
			if not Projectile.Lane.has(lane_name):
				push_warning("PatternSpawner: unknown lane '%s' skipped." % lane_name)
				continue
			lane = Projectile.Lane[lane_name]
		var beats := measure * beats_per_measure \
				+ float(note.get("step", 0)) / steps_per_beat
		_notes.append({"beats": beats, "lane": lane})
	# The conductor walks _notes front to back, so they must be in time order
	# no matter how the editor happened to serialize them.
	_notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["beats"] < b["beats"])
