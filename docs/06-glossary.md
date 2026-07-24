# Glossary

Quick reference so the other docs can use these terms freely.

## Godot terms

| Term | Meaning |
|---|---|
| **Node** | The basic building block. Everything in a Godot game is a node (sprite, timer, sound player, UI label). Nodes form a tree. |
| **Scene** | A saved tree of nodes (`.tscn` file). Scenes can be nested inside other scenes ("instancing"). Your player is a scene; the main game is a scene that contains it. |
| **Scene instancing** | Placing a saved scene inside another scene, or spawning one from code with `scene.instantiate()`. |
| **Script** | A `.gd` GDScript file attached to a node. It gives that node behavior. |
| **Signal** | Godot's event system. A node *emits* a signal ("I got hit!") and other nodes *connect* to it to react. Keeps code decoupled. |
| **Autoload (singleton)** | A script/scene Godot loads once at startup and keeps alive globally. Accessible from anywhere by name (e.g. `GameManager.score`). Registered in Project Settings → Globals. |
| **Resource** | A data container saved as a `.tres` file. Unlike nodes, resources are pure data — perfect for defining attacks/waves without code. |
| **`@export`** | Makes a script variable editable in the Inspector panel. **This is how you tweak the game without touching code.** |
| **`@onready`** | Assigns a variable when the node enters the scene (used to grab child nodes: `@onready var sprite = $Sprite2D`). |
| **`_ready()` / `_process(delta)` / `_physics_process(delta)`** | Lifecycle callbacks: runs once when the node loads / every rendered frame / every physics tick (fixed 60/s). |
| **Area2D** | An invisible zone that detects overlaps (things entering/leaving it). No physics, just detection. Our whole game runs on these. |
| **CharacterBody2D** | A physics body for characters that move and collide. **We don't need it** — our player never moves through space. |
| **CollisionShape2D** | The actual shape (rectangle, circle) that an Area2D or body uses for detection. |
| **Timer** | A node that counts down and emits `timeout`. Also available one-shot from code: `get_tree().create_timer(1.0)`. |
| **Tween** | Code-created animation: "move this property from A to B over 0.3s with easing." Our projectiles fly on tweens. |
| **`queue_free()`** | Safely deletes a node at the end of the frame. |
| **`modulate`** | A node's color tint. Tweening it gives you hit-flashes and fades. |
| **AnimatedSprite2D** | Node that plays frame-by-frame animations from a spritesheet. Simplest way to animate a character. |
| **SpriteFrames** | The resource holding an AnimatedSprite2D's named animations ("idle", "duck", ...). |
| **InputMap** | Project Settings tab where you name actions ("duck", "parry") and bind keys to them. Code checks actions, never raw keys. |
| **`user://`** | Godot's per-game writable folder (for the high score file). On Windows: `%APPDATA%\Godot\app_userdata\<project>`. |

## Genre / combat terms

| Term | Meaning |
|---|---|
| **Telegraph** | The warning before an attack (wind-up pose, color, sound). The player's reaction time budget lives here. |
| **Startup / active / recovery** | The three phases of any attack or player action: wind-up → the frames where it actually hits/works → cool-down where you're committed. |
| **Timing window** | The span of time during which an input counts (e.g. "the parry window is 150ms"). |
| **i-frames (invincibility frames)** | A short period after being hit where the player can't be hit again. Prevents unfair double-hits. |
| **Hitstop** | Freezing/slowing the game for ~0.1s on impact. Makes hits feel heavy. |
| **Screenshake** | Briefly shaking the camera on impact. Cheap, huge feel payoff. |
| **Input buffer** | Remembering a button press for ~120ms so a *slightly early* input still counts instead of being dropped. |
| **Coyote time / late grace** | Accepting an input slightly *after* the deadline. Together with buffering: "ties favor the player." |
| **Lane** | The direction/height an attack comes in at (high, low, left, right) — determines which player action beats it. |
| **Wave / pattern** | An authored sequence of attacks with timing, like a bar of music. |
| **Rest beat** | A deliberate pause between waves so the player can breathe. |
| **Fail-soft** | A missed input degrading to a lesser penalty instead of full damage (e.g. Sekiro: missed parry becomes a block). |
| **Juice** | Collective term for feedback polish: shake, flash, hitstop, particles, sound. |
| **Gray-boxing** | Building the game with placeholder rectangles first; art comes later. |
