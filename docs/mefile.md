# Instructions For Me — Desserted Desert Dessert (Phase 1, v3 dodge)

## Run it
1. Open Godot 4.7.1 → open the `dodge-guy-gamejam/` folder (that's the project, not the repo root).
2. Press **F5**.
3. You should see: a gray box on a ground line, `00:00:00` / `x1.0` / three hearts up top,
   a white stamina arc beside you, and rectangles blinking in, then flying at you.

## Controls
| Key | Action |
|---|---|
| **A** / Left Arrow | Dodge left |
| **D** / Right Arrow | Dodge right |
| **Space** / Up Arrow | Jump (dodge up) |
| **S** / Down Arrow | Duck (dodge down) |
| **J** | Parry |
| **Enter** / **R** | Restart (after game over) |

## How dodging works now (v3 — this changed!)
Dodging is **NOT** physically moving out of the way anymore. It's a **timing window
with a direction rule**:

- Pressing a dodge starts a short **active window** (`dodge_out + hang + return` ≈ 0.34s).
- A projectile arriving during that window is **neutralized — but only if your
  direction matches its lane**. It fades to a ghost and flies through you, harmless.
  It can never hit you, including when you snap back.
- Wrong direction (or no dodge) = it hits you, even though you "moved". The little
  hop is pure animation — the hitbox never moves.

**The rule (this is the game):**
| Lane | Comes from | The ONE answer |
|---|---|---|
| ABOVE | overhead, falls down your column | **sidestep (A or D)** |
| LEFT / RIGHT | horizontal, body height | **jump (Space)** |
| HEAD_LEFT / HEAD_RIGHT | horizontal, head height | **duck (S)** |

Parry (J) still beats any *parryable* attack from any lane during `parry_window`,
refunds stamina instantly, and locks you out during `parry_recovery` if you whiff.
Every dodge costs stamina; empty tank = the arc flashes red and you eat the hit.

**Want to change what beats what?** Edit the `LANE_ANSWERS` table at the top of
`scripts/player.gd` — plain text, one entry per lane, add a second direction to
any lane's list to give it two answers.

## Tuning — Inspector, no code (frames ÷ 60 = seconds)
### Player node
- **Dodge Feel**: `dodge_out_time` + `dodge_hang_time` + `dodge_return_time` = **the
  active window** (`dodge_hang_time` is the forgiveness knob). `dodge_distance` is
  now cosmetic only — the size of the flinch. `*_trans`/`*_ease` dropdowns = snappiness.
- **Parry**: `parry_window`, `parry_recovery` (whiff punishment), `parry_stamina_refund`.
- **Stamina**: `max_stamina`, `dodge_stamina_cost`, `stamina_regen`, `stamina_regen_delay`.
- **Health**: `max_hp`, `iframe_time`, `hit_recover_time`.
- **Input**: `input_buffer` (early presses still count).

### Spawner node
- **`max_alive`** — how many threatening shots can exist at once (my density lever).
- `start_interval` → `min_interval` over `ramp_seconds` — the difficulty curve.
- `lanes` — the deck; duplicate an entry to weight a lane, delete to retire it.
- `spawn_radius`, `despawn_radius`, `head_offset` (visual height of head shots).

### Attack `.tres` files (`resources/attacks/`)
`speed` (px/sec) · `telegraph_time` (never below ~0.4) · `damage` · `parryable` ·
`color`/`size` (identity) · **`ghost_alpha`** (how visible a dodged shot stays —
**set 0 to make dodged shots vanish**) · `deflect_speed_multiplier` · pulse look.

## My planned manual edits (recipes)
1. **One projectile type**: `main.tscn` → Spawner → Inspector → `Attacks` → keep
   only zippy (array size 1). Optionally delete `chonker.tres` / `spiker.tres`.
2. **Count + speed**: Spawner → `max_alive`; `zippy.tres` → `speed`.

## Flair spots (empty hooks that are mine)
Grep `## FLAIR:` — `_on_dodge_start`, **`_on_dodge_success`** (fires on a clean
dodge — juice goes here), `_on_parry_start`, `_on_parry_success`, `_on_hit`
(player.gd) · stamina arc `_draw` (stamina_arc.gd) · telegraph pulse (projectile.gd)
· ramp curve (spawner.gd).

## The map
Full architecture: `docs/07-map.md` (or `docs/07-map.html` — double-click to open
in a browser). Workflow: Phase 1 (done) → **me: play + tune** → Phase 2 (upgrades,
timer multiplier, juice, torch) → **me: author content** → Phase 3 (art, music, polish).
Numbers live in `docs/04-reaction-game-guide.md`. Feel problem? Knob first, code second.
