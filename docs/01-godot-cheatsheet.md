# Godot Cheatsheet (for a rusty-but-technical PM)

Target: **Godot 4.7.1 stable**, GDScript. Official docs: https://docs.godotengine.org/en/stable/ (the `stable` docs currently serve 4.7).

## 1. The mental model (10 lines)

- A game is a **tree of nodes**. Each node does one thing (draw a sprite, detect overlap, play a sound).
- You compose behavior by **adding child nodes**, not by writing big classes.
- A subtree can be saved as a **scene** (`.tscn`) and reused/spawned.
- A **script** (`.gd`) attached to a node gives it behavior; the script *is* that node (`self`).
- `$ChildName` grabs a child node. `%UniqueName` grabs a node marked unique anywhere in the scene.
- Nodes talk **up/outward via signals**, **down via direct calls** ("call down, signal up").
- **Autoloads** are global singletons for truly global stuff (score, event bus).
- **Resources** (`.tres`) are data files editable in the Inspector — our attack definitions.
- The **Inspector** shows every `@export` variable — that's the tuning dashboard.
- Press **F5** to run the project, **F6** to run just the currently open scene.

## 2. Lifecycle callbacks — which one do I use?

```gdscript
func _ready() -> void:          # runs ONCE when the node enters the tree. Setup here.
func _process(delta: float):    # every rendered frame. Visual stuff, timers you manage yourself.
func _physics_process(delta):   # fixed 60/s tick. Input checks + gameplay logic live here.
func _input(event):             # raw events. We mostly won't need it; polling Input is simpler.
```

`delta` = seconds since last call (~0.0166). Multiply anything per-second by `delta`.

## 3. The syntax you'll actually use

```gdscript
class_name Player            # registers a global type name (optional but nice)
extends Node2D               # what this script builds on

signal parried(attack)       # declare a signal (past tense verb)

@export var duck_duration := 0.4   ## How long a duck lasts, in seconds.
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
    sprite.play("idle")
    parried.connect(_on_parried)      # connect in code...
    parried.emit(null)                # ...emit like this

func _on_parried(attack) -> void:
    print("parried!")
```

- `:=` infers the type from the value (`var t := 0.0` is a float). Use explicit types when it's ambiguous.
- `##` comments become Inspector tooltips on the `@export` right above/beside them. Use them everywhere.
- `await get_tree().create_timer(0.5).timeout` pauses *this function* (not the game) for 0.5s.

## 4. Input: actions, not keys

Never check raw keys. Define **actions** once, check them by name.

**Editor setup (one time):** Project → Project Settings → **Input Map** tab → type an action name (e.g. `duck`) → Add → click **+** next to it → press the key. Create: `duck`, `jump`, `slide_left`, `slide_right`, `parry`, plus `restart`.

```gdscript
Input.is_action_just_pressed("parry")  # true ONLY the tick the key went down → use for parry/actions
Input.is_action_pressed("duck")        # true every tick while held → use for hold-to-stay-ducked (if wanted)
```

Check these in `_physics_process` so they align with gameplay ticks.

## 5. Why this game needs (almost) no physics

Our player never moves through the world — the world moves at the player. So:

- **No CharacterBody2D, no gravity, no `move_and_slide()`.** The "jump" is just an animation/state, not physics.
- Player = `Area2D` (hurtbox) + `AnimatedSprite2D`. Attacks = `Area2D` moving on a Tween.
- Overlap detection is the only "physics" we use:

```gdscript
# Area2D emits these when another area/body overlaps it:
func _on_area_entered(area: Area2D) -> void: ...
```

Connect signals in the editor: select the node → **Node** dock (next to Inspector) → double-click the signal → pick the target script. Godot generates the `_on_...` function.

## 6. Timers, Tweens, deleting things

```gdscript
# One-shot timer from code (no node needed):
await get_tree().create_timer(0.8).timeout

# Tween: animate any property. Created in code, starts immediately, one use only.
var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
tween.tween_property(self, "position", Vector2(320, 180), 0.6)  # (object, property, target, seconds)
tween.tween_callback(queue_free)   # runs after the property tween finishes (sequential by default)

queue_free()   # delete this node safely at end of frame
```

## 7. Spawning scenes from code

```gdscript
const ATTACK_SCENE := preload("res://scenes/attack.tscn")  # loaded at parse time

var attack := ATTACK_SCENE.instantiate()
attack.position = Vector2(700, 180)
add_child(attack)
```

## 8. Autoload registration

Project → Project Settings → **Globals** tab (called Autoload in older 4.x) → set Path to the script (e.g. `res://autoload/events.gd`), Name it (`Events`), Add. Now any script can call `Events.player_hit.emit(1)`.

## 9. Where things live

| What | Where |
|---|---|
| Project settings, input map, autoloads | Project → Project Settings |
| Animations for AnimatedSprite2D | Select the node → SpriteFrames panel at bottom |
| Signal connections | Node dock (tab next to Inspector) |
| Saved game data | `user://` (see glossary) |

## 10. Official doc links

- GDScript basics: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html
- Style guide: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html
- Your first 2D game (good skim): https://docs.godotengine.org/en/stable/getting_started/first_2d_game/index.html
- Tween: https://docs.godotengine.org/en/stable/classes/class_tween.html
- Area2D: https://docs.godotengine.org/en/stable/classes/class_area2d.html
- Custom resources: https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html
- 2D sprite animation: https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html
