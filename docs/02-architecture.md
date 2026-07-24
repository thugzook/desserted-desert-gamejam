# Architecture

The framework spec for our game. Every future coding session follows this. The cookbook (doc 03) has the actual code for each piece.

## 1. Folder layout

```
desserted-desert-gamejam/
├── project.godot
├── CLAUDE.md                  # conventions (auto-read by AI sessions)
├── docs/                      # this knowledge base
├── autoload/
│   ├── events.gd              # signal bus (autoload "Events")
│   └── game_manager.gd        # game state + score (autoload "GameManager")
├── scenes/
│   ├── main.tscn              # the game scene (player + spawner + HUD)
│   ├── player.tscn
│   ├── attack.tscn            # one generic projectile, configured by AttackData
│   └── ui/
│       ├── hud.tscn
│       └── game_over.tscn
├── scripts/                   # one .gd per scene above (player.gd, attack.gd, ...)
├── resources/
│   ├── attacks/               # AttackData .tres files (one per attack type)
│   └── waves/                 # WaveData .tres files (authored patterns)
└── assets/
    ├── art/
    ├── sfx/
    └── music/
```

## 2. Scene tree

```
Main (Node2D) ................. main.gd: starts waves, handles restart
├── Background (Sprite2D/ParallaxBackground)
├── Player (Area2D) ........... player.gd: THE state machine (see §3)
│   ├── AnimatedSprite2D
│   ├── CollisionShape2D ...... the hurtbox shape
│   └── ParryBox (Area2D) ..... only monitoring during PARRY
│       └── CollisionShape2D
├── AttackSpawner (Node2D) .... attack_spawner.gd: plays WaveData, spawns attacks
├── Camera2D .................. camera.gd: screenshake (trauma pattern)
└── HUD (CanvasLayer) ......... hud.gd: score, health hearts, game-over panel
```

The player sits at a fixed position (screen center-ish). Attacks are instantiated by the spawner at screen edges and tween toward the player.

## 3. Player state machine — enum + match, ONE script

The player's whole brain is one enum and one `match` statement in `player.gd`:

```gdscript
enum PlayerState { IDLE, DUCK, JUMP, SLIDE_LEFT, SLIDE_RIGHT, PARRY, HIT, DEAD }
```

### Transition rules

| State | Entered by | Exits after | Interruptible? |
|---|---|---|---|
| IDLE | game start; any action finishing | — | yes — any action input |
| DUCK | `duck` input | `duck_duration` (~0.4s) | no (committed) |
| JUMP | `jump` input | `jump_duration` (~0.5s) | no |
| SLIDE_LEFT / SLIDE_RIGHT | `slide_*` input | `slide_duration` (~0.4s) | no |
| PARRY | `parry` input | `parry_duration` (~0.3s; active window shorter) | no |
| HIT | taking damage | `hit_stun` (~0.5s), grants i-frames | no |
| DEAD | HP reaching 0 | never (restart reloads scene) | — |

- Actions are only accepted in IDLE, **but** inputs pressed during another action are held in a ~120ms **input buffer** and fire the moment IDLE returns (doc 04 explains why).
- Each action state has a single `@export`ed duration — tune everything in the Inspector.

### How dodging works (the core mechanic)

Every attack carries a `dodge_type` (which player action beats it). Resolution is a **state comparison, not collision-layer tricks**:

```
attack reaches the player
  → is the player's current state the attack's dodge_type?  → dodged (score!)
  → is the player in PARRY *active window* and attack.parryable? → parried (big score!)
  → else → player_hit
```

> Origin: the topdown template's `entities/hurt_box.gd` disables the hurtbox during "jump".
> We generalize that idea — but comparing `attack.dodge_type` to the player state in one
> function is far easier to debug than 5 collision layers. One `if`, visible in one file.

## 4. Autoloads — exactly two

### `Events` (autoload/events.gd) — the signal bus

Global events any node can emit/listen to without knowing each other. Stripped-down version of the topdown template's `Globals.gd` (signals only, no lookup helpers):

```gdscript
signal attack_spawned(attack)                # spawner → HUD/audio
signal attack_resolved(result: String, attack)  # "dodged" | "parried" | "hit" → score, juice
signal player_hit(damage: int)               # player → HUD hearts, camera shake
signal player_died                           # player → game over flow
signal score_changed(new_score: int)         # GameManager → HUD
signal game_state_changed(new_state)         # GameManager → everyone
```

Rule: use Events **only** for cross-system news. A node talking to its own child calls it directly.

### `GameManager` (autoload/game_manager.gd)

```gdscript
enum GameState { MENU, PLAYING, GAME_OVER }
```

Owns: current `GameState`, `score`, `high_score` (persisted with one `ConfigFile` at `user://highscore.cfg`). Listens to `Events.attack_resolved` to award points and `Events.player_died` to end the game. That's all it does.

## 5. Data-driven attacks — Resources

Designing a new attack = **creating a `.tres` file and filling Inspector fields.** No code.

### `AttackData` (scripts/attack_data.gd) — one attack type

```gdscript
class_name AttackData
extends Resource

enum DodgeType { DUCK, JUMP, SLIDE_LEFT, SLIDE_RIGHT, PARRY }

@export var display_name := ""          ## e.g. "Flying Donut"
@export var dodge_type: DodgeType       ## which player action avoids this attack
@export var parryable := false          ## can PARRY also beat it (for bonus)?
@export var telegraph_time := 0.6       ## seconds of warning before it starts moving fast
@export var travel_time := 0.5          ## seconds from spawn edge to the player
@export var damage := 1
@export var sprite_frames: SpriteFrames ## art for the projectile
@export var telegraph_sfx: AudioStream  ## unique warning sound (see doc 04)
```

(Adapted from the topdown template's `items/data_item.gd` pattern — a Resource with exports.)

### `WaveData` (scripts/wave_data.gd) — an authored pattern

```gdscript
class_name WaveData
extends Resource

@export var beats: Array[AttackData]    ## the attacks, in order
@export var gap := 1.0                  ## seconds between attacks in this wave
@export var rest_after := 2.0           ## breather before the next wave
```

The `AttackSpawner` takes an `Array[WaveData]` and plays them in order. Difficulty ramp = later waves have smaller `gap`/`telegraph_time` and more mixed types (doc 04 §5).

## 6. Why NOT the topdown template's node-based state machine

The template's `scripts/state_machine/` is genuinely good engineering: states are child nodes with lifecycle methods, chained by `on_completion` arrays, saved/restored by index. But it exists to serve ~25 states across players, NPCs, props, and dialogue — problems we don't have. The costs for us:

- **Indirection:** understanding one behavior means reading `state_machine.gd` (154 lines) + `state.gd` (94 lines) + the leaf state + the scene wiring that connects them.
- **Invisible flow:** transitions live in exported node references scattered across the Inspector, not in one readable function.
- **8 states, 1 entity:** our entire state logic fits in ~120 lines of one file with a `match` you can read top to bottom.

If the game somehow grows past ~10 states or a second complex entity, graduate then. For one week: enum + match.

## 7. Naming contract (used verbatim across all code)

- States: `IDLE, DUCK, JUMP, SLIDE_LEFT, SLIDE_RIGHT, PARRY, HIT, DEAD`
- Dodge types: `DUCK, JUMP, SLIDE_LEFT, SLIDE_RIGHT, PARRY`
- Resolution results: `"dodged"`, `"parried"`, `"hit"`
- Input actions: `duck`, `jump`, `slide_left`, `slide_right`, `parry`, `restart`
- Signals: as listed in §4. Past-tense verbs.
