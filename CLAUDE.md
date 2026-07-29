# CLAUDE.md — Desserted Desert Dessert

Game jam entry (hackrva, ~1 week, July 2026). **Godot 4.7.1 stable** (binary in the user's Downloads); docs target 4.7 APIs. **GDScript.**
Endless survival dodge/parry game: player on a ground line at bottom-center, projectiles fly in, you dash-and-return in 4 directions, parry for stamina, and survive as long as possible. Score is the timer.

**The Godot project lives in `dodge-guy-gamejam/` inside this repo** — `project.godot` is there, not at the repo root, and `res://` resolves to that folder. The root holds only this file and `docs/`.

The user is a PM with technical background. **Two prime directives:**

1. **They own the feel; you own the plumbing.** They should never write scaffolding, wiring, or boilerplate. Their job is mechanics, features, and tuning.
2. **Every gameplay number is an Inspector knob.** If they'd want to change it while playtesting, it's an `@export` with a `##` comment saying which direction does what.

## Phase discipline — the most important rule here

Work is handed off **Phase 1 → user → Phase 2 → user → Phase 3** (`docs/02` §1).

- **Build exactly one phase per session, then stop.** Do not start the next phase's features because there's time left. The user tunes and playtests between phases; that feedback shapes what comes next.
- A phase is done when the project **opens in Godot, F5 runs a complete loop (play → die → restart)**, and every knob in that phase's tuning table is in the Inspector.
- Never hand off a half-built system. If something must be cut to finish the phase, cut it and say so — see `docs/05` §3 for the order.

## Doc index

| Doc | Read when… |
|---|---|
| `docs/00-game-brief.md` | starting any session — the user's spec, and their answers. Their edits always win. |
| `docs/02-architecture.md` | **always, before writing game code** — phases, folder layout, scene tree, state model, tuning surface, naming contract (§12) |
| `docs/03-patterns-cookbook.md` | implementing Phase 1 — the complete code is already written here; copy it, don't reinvent it |
| `docs/04-reaction-game-guide.md` | choosing or defending any timing number — has the researched values and sources |
| `docs/05-scope-and-antipatterns.md` | tempted to add a system — probably vetoed there; also the day plan and cut list |
| `docs/01-godot-cheatsheet.md` | the user asks how Godot works, or you need editor-step wording |
| `docs/06-glossary.md` | a term is unclear |

## You write the scene files

**Generate `.tscn` and `project.godot` as text.** Godot scene files are plain text and hand-writing them is how the user gets a working project instead of a to-do list of editor clicks. This overrides the usual caution about editing scene files.

- After generating, tell the user to open the project and press F5, and give them a one-line "you should see X" so a failure is obvious.
- If a `.tscn` won't load, fix the file — don't fall back to instructions.
- **Exception:** things that genuinely need the GUI (importing art, drawing a Curve, recording SpriteFrames) — describe those as numbered steps.

## Coding conventions

Follow the official GDScript style guide (https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html). Specifically:

- **Naming:** `snake_case` files/functions/variables · `PascalCase` for `class_name` and node names · `CONSTANT_CASE` constants and enum members · signals are **past-tense verbs** (`parried`, `player_hit`).
- **Script order:** `class_name` → `extends` → `##` doc comment → signals → enums → consts → `@export` vars → vars → `@onready` vars → `_ready`/built-ins → public funcs → private (`_`) funcs.
- **Tunables:** every feel number is an `@export` in an `@export_group`, with a `##` comment stating what raising it does. Never a `const` — Phase 2 upgrades mutate these at runtime.
- **Durations in seconds, frames in the comment** (60 ticks/sec): `@export var dodge_out_time := 0.08 ## Seconds to dash out (0.08 = 5 frames). Lower = snappier.`
- **"Call down, signal up":** a node may call its children directly; it talks to parents/siblings/systems via signals. Cross-system news goes through `Events` only. Never reach across the tree with `$"../../Node"`.
- **Types:** `:=` where the value makes the type obvious; explicit types on function signatures.
- **Size:** target < 200 lines per script. If one grows past that, propose a split before doing it.
- **Comments:** a `##` docstring on every script; inline comments explain *why*, never *what*.
- **`## FLAIR:` markers** on hooks the user is meant to fill (`_on_dodge_start`, `_on_parry_start`, `_on_parry_success`, `_on_hit`, `_draw` on the stamina arc). Leave them empty or minimal — don't fill them without being asked.

## Architecture invariants

- **Dodging is a timed window + one visible rule table; the hurtbox does NOT move (v5, user decision 2026-07-27).** A shot is dodged only if its direction is in `LANE_ANSWERS[lane]` (`player.gd` — the ONLY place the rule may live). Only the sprite nudges, so every shot reaches `_resolve()` and geometry never gets a vote. The active window is `dodge_out_time + dodge_hang_time + dodge_return_time` and runs to completion — **nothing but the tween callback may set `state` back to `READY`**; a successful dodge must not end the window (that bug made the first shot you dodged correctly the last one you were safe from). Lanes aim at `home_position`.
- **A dodge COMMITS you; landing anything releases it (user decision 2026-07-27).** Starting a dodge locks out further dodge input for the whole animation — but `_dodge_success()` or `_parry_success()` sets `_dodge_scored`, which frees you instantly. One rule: *"land anything, keep moving; whiff and you're stuck."* This exists because the animation (0.34s) is longer than the 8th-note gap in `patterns/test_pattern.json` (0.30s at 100 BPM), so without the release those notes are unanswerable. Knob: `dodge_commits`, default on. **The lock lives in `_can_dodge_now()` only, and must never gate the parry branch of `_consume_buffer()`** — parrying mid-dodge stays free (see the parry invariant below).
  - v4's moving hurtbox (2026-07-26) is kept behind `@export var dodge_moves_hurtbox`, default **off**. It failed because `dodge_distance` (25, 20) is ~10% of the 190×190 hurtbox: it cleared no lane, and head/feet lanes — aimed at `±player_size.y/2`, which grazes the hurtbox edge by ~1px — lost contact entirely, so correct dodges fired no `ghost()` and gave zero feedback. Turning it on requires re-deriving `spawner.gd:lane_endpoints()` from the hurtbox and a full re-tune.
- **Stamina is DISABLED (user decision 2026-07-26)** — every call site is commented with a `STAMINA DISABLED` marker (player.gd + hud.gd); grep it to re-enable. Don't build new features on stamina without asking.
- **Parry is a timer, not a state.** `parry_time` must never touch `state` — that's what makes parrying mid-dodge work for free.
- Player movement state is **`enum State { HOME, DODGING, HIT, DEAD }`** in `player.gd`. No node-based state machines (rationale: `docs/05` §1).
- Exactly **two autoloads**: `Events` (signal bus) and `Game` (run state + timer). No new autoloads without asking.
- Player is an **`Area2D` moved by a Tween** — no `CharacterBody2D`, no gravity, no physics simulation anywhere.
- Attacks are **data**: one `projectile.tscn` + one `ProjectileData` `.tres` per attack type. A new attack is a new `.tres`, never new code.
- Restart is `get_tree().reload_current_scene()`. No reset system.
- Anything in `docs/05` §1's antipattern table is vetoed by default — cite the table when declining.

## Workflow rules

- **Propose before building:** 2–3 sentences on the approach (referencing the cookbook section), get a yes, then write.
- **Keep the game runnable.** Never end a turn with a project that won't F5.
- **Small commits**, imperative messages ("Add parry window", not "Added stuff").
- **Timing questions get numbers from `docs/04`**, not vibes.
- **When the user reports a feel problem, reach for a knob before reaching for code.** "Parries feel impossible" → raise `parry_window`. Only change structure when no knob covers it.
- When behind schedule, cut per `docs/05` §3 — never cut the input buffer, mercy i-frames, or restart-on-death.

## Reference repos (siblings of this folder — read-only)

- `../godot-2d-topdown-template` — source of the signal-bus shape, the hurtbox idea, and the Resource-as-data pattern. Do **not** copy its state machine, SceneManager, or DataManager (`docs/05` §1).
- `../simple-2d-platformer` — style reference for small, readable, commented scripts; source of the restart flow.
