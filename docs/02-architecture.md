# Architecture (v2)

The framework for "Desserted Desert Dessert". Rewritten from v1 to match the user spec in `docs/00-game-brief.md` (collision-based dodging, parry-anywhere, stamina, dash-and-return).

**Two rules drive every decision in this doc:**

1. **The AI writes the plumbing; you write the feel.** Scene files, wiring, autoloads, and the game loop are generated for you. Your surface is the Inspector and a handful of clearly-marked hook functions.
2. **One phase per session, with you in the middle.** Phase 1 → *you play and tune* → Phase 2 → *you play and tune* → Phase 3.

---

## 1. The handoff model

Each phase ends with a game you can run with **F5** and tune without writing code. The build session stops there and hands you a tuning pass.

```
┌── PHASE 1 (AI) ──────────┐   ┌── YOU ────────────┐   ┌── PHASE 2 (AI) ──┐   ┌── YOU ──┐   ┌── PHASE 3 ──┐
│ running prototype:       │   │ • play it         │   │ upgrades         │   │ tune +  │   │ polish,     │
│ timer, health, dodge,    │──▶│ • tune Inspector  │──▶│ multiplier       │──▶│ author  │──▶│ art, music, │
│ parry, stamina,          │   │   numbers         │   │ juice, light     │   │ upgrade │   │ stretch     │
│ projectiles, HUD         │   │ • say what's fun  │   │                  │   │ content │   │             │
└──────────────────────────┘   └───────────────────┘   └──────────────────┘   └─────────┘   └─────────────┘
```

**What "done" means for a phase:** the project opens in Godot, F5 runs a complete loop (play → die → restart), and every number listed in that phase's tuning table is visible in the Inspector. No half-built systems carried across a handoff.

> **Where the project lives:** the Godot project is the **`dodge-guy-gamejam/`** subfolder of this repo (the user created it) — `project.godot` is in there, *not* at the repo root. Every `res://` path in these docs resolves inside that folder: `res://scripts/player.gd` is `dodge-guy-gamejam/scripts/player.gd` on disk. The repo root holds only `CLAUDE.md` and `docs/`.

### Phase 1 — the prototype you tune (6 systems, ~8 files)

Timer · Health · 4-direction dodge · Parry · Stamina · Projectiles + HUD, plus **high-score persistence** (one `ConfigFile` in `Game` — trivial, so it ships now).
Gray rectangles for everything. No upgrades, no multiplier, no juice.

### Phase 2 — the risk/reward layer

Upgrade pickups (mild / risky tiers) · timer multiplier · game-feel pass (hitstop, shake, flash, SFX) · light/torch system.

### Phase 3 — stretch

Cursed items · music · real art · controls-remap menu · anything cut earlier.

---

## 2. Folder layout

**The repo root is not the Godot project.** The project lives one level down, in `dodge-guy-gamejam/` — that's where `project.godot` sits, and that folder is what you open in Godot. `res://` = that folder.

```
desserted-desert-gamejam/        # repo root — NOT a Godot project
├── CLAUDE.md                    # conventions for AI sessions
├── docs/                        # this knowledge base
└── dodge-guy-gamejam/           # ← the Godot project. res:// points HERE.
    ├── project.godot            # generated: input map, window size, autoloads
    ├── autoload/
    │   ├── events.gd            # signal bus  (autoload name: Events)
    │   └── game.gd              # run state + timer  (autoload name: Game)
    ├── scenes/
    │   ├── main.tscn            # the game
    │   ├── player.tscn
    │   ├── projectile.tscn      # ONE scene for every attack type
    │   └── hud.tscn
    ├── scripts/
    │   ├── main.gd  player.gd  projectile.gd  spawner.gd  hud.gd
    │   ├── stamina_arc.gd       # the Deadlock-style pips — a FLAIR file
    │   └── projectile_data.gd   # Resource: defines an attack type
    └── resources/attacks/       # .tres files — YOUR attack designs
```

## 3. Scene tree

```
Main (Node2D) ................. main.gd — start/restart, holds the pieces
├── Ground (ColorRect) ........ the line the player stands on
├── Player (Area2D) ........... player.gd — dodge, parry, stamina, health
│   ├── Sprite (ColorRect) .... gray box for now
│   └── CollisionShape2D ...... the hurtbox. Moves with the player. That's the whole dodge system.
├── Spawner (Node2D) .......... spawner.gd — picks attacks, ramps difficulty
│                                 Sits at (0,0): its spawn math is in Main's space,
│                                 offset from player.home_position, so leave it there.
├── Camera2D
└── HUD (CanvasLayer) ......... hud.gd — timer, multiplier, hearts, stamina arc
    ├── TimeLabel ............. 00:00:00, top center
    ├── MultiplierLabel ....... "x1.0" beside the timer (static in Phase 1)
    ├── HeartsLabel ........... "♥" × max_hp, under the timer
    ├── StaminaArc (Control) .. stamina_arc.gd — _draw()s the pips
    └── GameOverPanel (Panel)
        └── ResultLabel ....... TIME / BEST
```

---

## 4. The core mechanic: dodging is collision, not matching

**Dodging requires zero code.** The player's hurtbox physically moves out of the way. If it moved far enough, the projectile's `area_entered` never fires and nothing happens — there is no "did they dodge correctly?" check anywhere in the codebase.

> This is the change from v1, which matched a `dodge_type` on the attack against the player's state. That system couldn't answer "what if I jump into an unavoidable mix of projectiles?" — this one doesn't have to ask.

Everything that *does* happen on contact lives in one function:

```
projectile touches player
  → parry window active AND attack is parryable?  → PARRIED  (refund stamina, deflect it)
  → invincibility frames still running?            → ignored
  → otherwise                                      → HIT      (−1 heart, i-frames start)
```

Three branches, one place to look when you ask "why did that hit me?"

## 5. Player state: one enum + two timers

The player is **not** a full state machine. Movement is a 4-state enum; parry and invincibility are independent timers that run *alongside* it.

```gdscript
enum State { HOME, DODGING, HIT, DEAD }
var parry_time  := -1.0   # -1 = not parrying; counts up while parrying
var iframe_time :=  0.0   # counts down after a hit
```

**Why timers and not states:** because `parry_time` doesn't touch `state`, **you can parry mid-dodge** — the spec's airborne-parry requirement is satisfied by *not writing code*, rather than by adding a state-transition rule.

| Movement state | Entered by | Leaves when |
|---|---|---|
| `HOME` | start; any dodge finishing | a dodge starts |
| `DODGING` | dodge input (costs stamina) | the dodge tween completes |
| `HIT` | taking damage (cancels the dodge) | recovery tween returns you home |
| `DEAD` | HP reaches 0 | never — restart reloads the scene |

### The dodge: out → hang → back

Per the spec, a dodge is **snappy dash-and-return**: move fast to the offset position, *hang there*, snap back home. The whole choreography is one Tween whose three steps map 1:1 to three Inspector numbers:

```
dodge_out_time  ──▶  dodge_hang_time  ──▶  dodge_return_time
   (dash out)          (hang there)          (snap home)
```

The hang is the window where you're actually out of the projectile's path. Longer hang = more forgiving. This is your single most important feel knob.

### Parry: a window, not a state

`parry_time` counts up from 0. The **first** `parry_window` seconds deflect; the remaining time up to `parry_recovery` is the animation lock where a whiffed parry leaves you exposed — exactly the risk/reward the spec asks for. Success refunds stamina instantly.

## 6. Stamina

One float. Dodging spends it, a successful parry refunds it, it regenerates after a short delay (so spamming dodges doesn't regen through the cost). At zero you can't dodge — that's the "passive blocker" from the brief. Displayed as the Deadlock-style arc around the player.

**The arc doesn't follow the player.** It's a `Control` in the HUD `CanvasLayer`, parked at the player's *home* position on screen. Since the camera never moves, screen coordinates and world coordinates are the same, so "home position" is a fixed pair of numbers. Parenting it to the player would make it swing around during every dodge — exactly when you need to read it. It stays put; the player dashes out from under it and comes back.

## 7. Autoloads — exactly two

**`Events`** (`autoload/events.gd`) — a signal bus so systems don't need references to each other:

```gdscript
signal player_hit(hp_left: int)
signal player_died
signal parried(projectile)
signal dodged(direction: Vector2)
signal dodge_failed          ## no stamina — cue a UI flash
signal stamina_changed(current: float, max_value: float)
signal run_started
signal run_ended(time_survived: float)
```

**`Game`** (`autoload/game.gd`) — run state (`MENU`/`PLAYING`/`GAME_OVER`), the survival timer, best time. In Phase 1 **your score is the timer**. Nothing else lives here.

> Rule: `Events` carries *news between systems*. A node talking to its own child calls it directly.

## 8. Attacks are data, not code

`ProjectileData` is a Resource. **One `projectile.tscn` renders every attack type** — the resource supplies speed, telegraph, damage, size, and color. Designing a new attack means making a `.tres` file and filling in fields; it never means writing code.

| Field | What it controls |
|---|---|
| `speed` | pixels/second once launched |
| `telegraph_time` | seconds it sits still, visible, before launching |
| `damage` | hearts lost |
| `parryable` | can the parry window deflect it |
| `color`, `size` | its look — how the player tells attack types apart |

*(Adapted from the topdown template's `items/data_item.gd` pattern: a `Resource` with `@export`s, instanced as `.tres` files.)*

**Phase 1 spawning is a ramp, not authored waves.** The spawner picks randomly from your attack list and shrinks the interval from `start_interval` to `min_interval` over `ramp_seconds`. Three numbers = your whole difficulty curve. Hand-authored wave sequences were in the v1 plan; they're cut as unnecessary scaffolding for an endless survival game. If you later want set-piece patterns, that's a Phase 3 addition.

## 9. Phase 2 hooks (designed for, not built yet)

Phase 1 leaves these seams open so Phase 2 doesn't require rewrites:

- **Timer multiplier** → `Engine.time_scale`. Everything already moves via `speed * delta`, so raising the scale speeds the whole game *and* the survival clock at once — one property implements "go faster for more score." (Note it interacts with hitstop; the juice code handles that.)
- **Upgrades** → an `UpgradeData` Resource that modifies the player's exported values at runtime. Phase 1 keeps every tunable a plain `@export var` (not a `const`) specifically so upgrades can mutate them.
- **Light/torch** → a `PointLight2D` + `CanvasModulate` on Main. No structural change.

---

## 10. Your tuning surface

Everything below is an Inspector field. **Godot's physics runs at 60 ticks/second, so `frames ÷ 60 = seconds`:**

| Frames | 3 | 5 | 6 | 9 | 12 | 15 | 18 | 24 |
|---|---|---|---|---|---|---|---|---|
| **Seconds** | 0.05 | 0.08 | 0.10 | 0.15 | 0.20 | 0.25 | 0.30 | 0.40 |

### On the Player (grouped in the Inspector)

| Group | Knobs | Turn it up to… |
|---|---|---|
| **Dodge Feel** | `dodge_distance`, `dodge_out_time`, `dodge_hang_time`, `dodge_return_time`, `dodge_out_trans`, `dodge_return_trans`, `dodge_out_ease`, `dodge_return_ease` | move further / dash slower / **hang longer (more forgiving)** / return slower. The `*_trans` and `*_ease` dropdowns are the easing curve — this is what "snappy" actually is. |
| **Parry** | `parry_window`, `parry_recovery`, `parry_stamina_refund` | widen the success window / lengthen the whiff punishment / pay out more |
| **Stamina** | `max_stamina`, `dodge_stamina_cost`, `stamina_regen`, `stamina_regen_delay` | more dodges before empty / cheaper dodges / faster recovery |
| **Health** | `max_hp`, `iframe_time`, `hit_recover_time`, `hit_recover_trans` | more hearts / longer mercy invincibility / how the stagger back home reads |
| **Input** | `input_buffer` | how early a press still counts (leniency) |

### On the Spawner

`start_interval`, `min_interval`, `ramp_seconds`, `spawn_radius`, `attacks` (the list of `.tres` files), plus:

| Knob | What it does |
|---|---|
| `despawn_radius` | how far past the screen a missed attack flies before deleting itself. Keep it well above `spawn_radius`. |
| `lanes` | **the deck of directions**: `ABOVE` (falls down your column — sidestep it), `LEFT`/`RIGHT` (body height), `HEAD_LEFT`/`HEAD_RIGHT` (head height — **duck under with S**). Duplicate an entry to make that lane more common; remove one to retire it. |
| `head_offset` | how far above center "head height" is. Must stay in the top half of the hurtbox (≈ −8 to −20) or head shots whiff a standing player. |

### On each attack `.tres`

| Knob | What it does |
|---|---|
| `display_name` | label for you in the Inspector; not shown in-game |
| `speed`, `telegraph_time`, `damage`, `parryable` | the attack itself (see §8) |
| `color`, `size` | its identity — how the player tells types apart |
| `deflect_speed_multiplier` | how hard a parry sends it back. Higher = more power fantasy. |
| `pulse_rate`, `pulse_min_alpha` | the telegraph flash: how fast it blinks and how faint it goes |

**Starting values and the research behind them** (why parry ≈ 150 ms, why telegraphs ≥ 600 ms, why ties should favor you) are in `docs/04-reaction-game-guide.md`. Tune against that doc, not against instinct.

## 11. Where you add your own flair

Phase 1 code carries explicit markers. These are yours; the AI won't fill them without being asked:

- `## FLAIR:` — a deliberately empty or minimal hook. `_on_dodge_start()`, `_on_parry_start()`, `_on_parry_success()`, `_on_hit()` on the player, and `_draw()` on the HUD's stamina arc. Each carries its own `## FLAIR:` line, so grepping the project for `## FLAIR:` lists them all.
- `## TUNE:` — a number with a note about which direction changes what.
- `resources/attacks/*.tres` — your attack designs. The three shipped with Phase 1 are placeholders to delete.

## 12. Naming contract (used verbatim in all code)

- States: `HOME`, `DODGING`, `HIT`, `DEAD`
- Input actions: `dodge_left`, `dodge_right`, `dodge_up`, `dodge_down`, `parry`, `restart`
  (Phase 1 default binding: **A / D / Space / S**, parry on **J**. Arrow keys bound to the same actions.
  `restart` is bound to **Enter and R**, and only does anything in `GAME_OVER`.)
- Signals: as listed in §7, past tense.
- Class names: `Player`, `Projectile`, `ProjectileData`, `Spawner`.
