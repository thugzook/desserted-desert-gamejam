# CLAUDE.md — Desserted Desert Dessert

Game jam entry (hackrva, ~1 week, July 2026). **Godot 4.7.1 stable, GDScript.**
Concept: 2D sprite fixed at screen center; dessert-themed attacks fly at it; the player **ducks, jumps, slides left/right, and parries**. Stationary-player reaction game (Punch-Out / rhythm-dodge kin).

The user is a PM with technical background. **Prime directive: everything built must stay understandable and tweakable by them.** Simple and readable beats clever, every time.

## Doc index (read before writing code)

| Doc | Read when… |
|---|---|
| `docs/00-game-brief.md` | starting any session — the design source of truth (user edits win) |
| `docs/01-godot-cheatsheet.md` | the user asks how Godot works, or you need editor-step wording |
| `docs/02-architecture.md` | **always, before writing any game code** — folder layout, scene tree, state machine spec, naming contract (§7) |
| `docs/03-patterns-cookbook.md` | implementing anything — the code probably already exists here; copy it |
| `docs/04-reaction-game-guide.md` | tuning timings, authoring waves, or judging difficulty — has the researched numbers |
| `docs/05-scope-and-antipatterns.md` | tempted to add a system — probably vetoed there; also the week schedule |
| `docs/06-glossary.md` | a term is unclear |

## Coding conventions

Follow the official GDScript style guide (https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html). Specifically:

- **Naming:** `snake_case` files/functions/variables · `PascalCase` for `class_name` and node names · `CONSTANT_CASE` constants and enum members · `PascalCase` enum names · signals are **past-tense verbs** (`attack_resolved`, not `on_attack`).
- **Script order:** `class_name` → `extends` → `##` doc comment → signals → enums → consts → `@export` vars → vars → `@onready` vars → `_ready`/built-ins → public funcs → private (`_`) funcs.
- **Every gameplay number is an `@export` with a `##` doc comment.** No magic numbers in function bodies. This is non-negotiable — it's how the user tunes the game in the Inspector.
- **"Call down, signal up":** a node may call its children directly; it talks to parents/siblings/systems via signals. Cross-system news goes through the `Events` autoload only (its 6 signals are listed in `docs/02` §4 — extend deliberately, not casually).
- **Types:** use `:=` inference where the value makes the type obvious; explicit types on function signatures and anything ambiguous.
- **Size:** target < 150 lines per script. If a script grows past that, propose a split to the user first.
- **Comments:** a `##` docstring on every script saying what it is; inline comments explain *why*, never *what* the next line does.
- **Naming contract** (states, dodge types, result strings, input actions, signal names): `docs/02` §7, verbatim, everywhere.

## Architecture invariants

- Player state machine = **enum + match in `player.gd`**. Never introduce node-based state machines (rationale: `docs/02` §6).
- Exactly **two autoloads**: `Events` (signal bus) and `GameManager` — plus optionally the music player scene. No new autoloads without asking the user.
- Attacks/waves are **data** (`AttackData`/`WaveData` `.tres` in `resources/`). New attack = new `.tres`, not new code. If a feature can be an exported field instead of a branch, make it a field.
- Player is an `Area2D` — no physics bodies, no gravity anywhere in the project.
- Restart = `get_tree().reload_current_scene()`. No reset systems.
- Anything in `docs/05` §1's antipattern table is vetoed by default; cite the table when declining.

## Workflow rules for AI sessions

- **Propose before writing:** for any new system, state the approach in 2–3 sentences (with cookbook pattern reference) and get a yes before generating code.
- **Keep the game runnable:** never leave the project in a state where F5 fails. One working feature at a time.
- **Scene wiring (.tscn):** prefer giving the user short numbered editor steps (see `docs/01` for phrasing) over hand-editing `.tscn` files; if you must edit a `.tscn`, keep the diff minimal and explain it.
- **Small commits**, imperative messages ("Add parry state", not "Added stuff").
- **Tuning questions get numbers from `docs/04`**, not vibes (telegraph ≥600ms early, parry window ~150ms, buffer 120ms, ties favor the player).
- When behind schedule, cut per `docs/05` §3's ordered list — never cut teaching waves, input buffer, or restart flow.
- Day-by-day plan and "definition of done" per day: `docs/05` §2.

## Reference repos (siblings of this folder — read-only inspiration)

- `../godot-2d-topdown-template` — where the signal bus, hurtbox idea, Resource pattern came from. Do **not** copy its state machine/SceneManager/DataManager (docs/05 §1).
- `../simple-2d-platformer` — style reference for small, readable, commented scripts.
