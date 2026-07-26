class_name PatternSpawner
extends Node2D
## Plays an authored beat pattern (JSON from tools/pattern-editor.html) on loop.
##
## A note in the pattern marks when the attack ARRIVES at the player — the moment
## they must dodge or parry — not when it spawns. This node works backwards and
## spawns each shot lead_time() seconds early (telegraph + travel), which is what
## keeps the attacks landing on the beat.
##
## Coordinate assumption: same as Spawner — this node sits at (0, 0) in main.tscn,
## and all aiming math is shared via Spawner.lane_endpoints().

## Lane string in the JSON meaning "keep the beat, hide the direction" —
## the actual lane is rolled from `lanes` the moment the note spawns.
const ANY_LANE := "ANY"

@export var projectile_scene: PackedScene
## TUNE: the one attack type every note uses. One attack = one uniform lead time,
## which keeps "arrives on the beat" easy to reason about. Per-note attacks are a
## later feature, on purpose.
@export var attack: ProjectileData
@export var player: Player

@export_group("Pattern")
## The pattern to loop forever. Author it in tools/pattern-editor.html, export,
## drop the .json into res://patterns/, and point this at it.
@export_file("*.json") var pattern_path := "res://patterns/test_pattern.json"
## 0 = use the BPM saved in the pattern file. Set above 0 to override — raising
## it speeds the whole song up without editing the pattern.
@export var bpm_override := 0.0
## Beats of silence before measure 1 the first time through. Reaction runway —
## keep it at least ~3 so the very first note still gets its full telegraph.
@export var lead_in_beats := 4.0
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


func _ready() -> void:
	_load_pattern()


func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING or _notes.is_empty() or player == null:
		return
	_song_time += delta
	# Fire every note whose ARRIVAL falls within lead_time of now. Usually zero or
	# one per frame; the while catches dense 16th clusters after a lag spike.
	while _arrival_seconds(_next_note) <= _song_time + lead_time():
		_spawn(_notes[_next_note])
		_next_note += 1
		if _next_note >= _notes.size():  # pattern wraps — loop forever
			_next_note = 0
			_loop += 1


## Seconds between a shot spawning and reaching the player: telegraph + travel.
## Every lane travels spawn_radius pixels (see Spawner.lane_endpoints), so one
## number serves all seven.
func lead_time() -> float:
	return attack.telegraph_time + spawn_radius / attack.speed


# --- private ---------------------------------------------------------------


## When note `i` of the CURRENT loop arrives at the player, in song seconds.
func _arrival_seconds(i: int) -> float:
	var beats: float = lead_in_beats + _loop * _loop_beats + _notes[i]["beats"]
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


## Read and validate the pattern file. Bad notes are logged and skipped — a typo
## in a lane name must never crash a run.
func _load_pattern() -> void:
	var text := FileAccess.get_file_as_string(pattern_path)
	if text.is_empty():
		push_error("PatternSpawner: can't read '%s' — no attacks will spawn." % pattern_path)
		return
	var data: Variant = JSON.parse_string(text)
	if data == null or not data is Dictionary:
		push_error("PatternSpawner: '%s' isn't valid JSON — no attacks will spawn." % pattern_path)
		return

	var bpm := bpm_override if bpm_override > 0.0 else float(data.get("bpm", 100.0))
	_seconds_per_beat = 60.0 / bpm
	var beats_per_measure := float(data.get("beats_per_measure", 4))
	var steps_per_beat := float(data.get("steps_per_beat", 4))
	_loop_beats = float(data.get("measures", 10)) * beats_per_measure

	for note: Dictionary in data.get("notes", []):
		var lane_name := str(note.get("lane", ""))
		var lane := -1
		if lane_name != ANY_LANE:
			if not Projectile.Lane.has(lane_name):
				push_warning("PatternSpawner: unknown lane '%s' skipped." % lane_name)
				continue
			lane = Projectile.Lane[lane_name]
		var beats := float(note.get("measure", 0)) * beats_per_measure \
				+ float(note.get("step", 0)) / steps_per_beat
		_notes.append({"beats": beats, "lane": lane})
	# The conductor walks _notes front to back, so they must be in time order
	# no matter how the editor happened to serialize them.
	_notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["beats"] < b["beats"])
