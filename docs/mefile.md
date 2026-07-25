I can't write files in this response, but here's the complete markdown ready to paste — save it as `INSTRUCTIONS-FOR-ME.md` in your repo root (or ask in the main chat and it'll be saved and committed for you):

```markdown
# Instructions For Me — Desserted Desert Dessert (Phase 1)

## Run it
1. Open Godot 4.7.1 → import/open the `dodge-guy-gamejam/` folder (that's the project, not the repo root).
2. Press **F5**.
3. You should see: a gray box on a ground line, `00:00:00` / `x1.0` / three hearts up top,
   a white stamina arc beside you, and colored rectangles blinking in, then flying at you.

## Controls
| Key | Action |
|---|---|
| **A** / Left Arrow | Dodge left |
| **D** / Right Arrow | Dodge right |
| **Space** / Up Arrow | Dodge up (jump) |
| **S** / Down Arrow | Duck |
| **J** | Parry |
| **Enter** / **R** | Restart (after game over) |

Every dodge costs stamina. A successful parry refunds stamina instantly.
A whiffed parry locks you in recovery (the risk). Empty tank = the arc flashes red.

## Attack lanes — what beats what
Attacks come from exactly five lanes; each has a natural answer, but ANY dodge
that physically clears the flight path works (collision decides, not rules):

| Lane | Comes from | Natural answer |
|---|---|---|
| ABOVE | straight overhead, falls down your column | **sidestep (A/D)** — ducking keeps you in its path |
| LEFT / RIGHT | horizontal, body height | step away, jump, or parry |
| HEAD_LEFT / HEAD_RIGHT | horizontal, head height | **duck (S)** — it sails over you |

## Tuning — everything is in the Inspector, no code
Click a node, look at the Inspector. 60 physics ticks/sec, so frames ÷ 60 = seconds
(5 f = 0.08s · 9 f = 0.15s · 12 f = 0.20s).

### Player node
- **Dodge Feel**: `dodge_distance`, `dodge_out_time` (dash-out speed),
  `dodge_hang_time` (**the forgiveness knob** — how long you hang out of harm's way),
  `dodge_return_time`, plus `*_trans` / `*_ease` dropdowns (this is what "snappy" is).
- **Parry**: `parry_window` (0.15 = 9 frames), `parry_recovery` (whiff punishment),
  `parry_stamina_refund`.
- **Stamina**: `max_stamina`, `dodge_stamina_cost`, `stamina_regen`, `stamina_regen_delay`.
- **Health**: `max_hp`, `iframe_time` (mercy invincibility), `hit_recover_time`.
- **Input**: `input_buffer` (early presses still count — leniency).

### Spawner node
- **Difficulty**: `start_interval` → `min_interval` over `ramp_seconds` = the whole curve.
- **Lanes**: `lanes` array — duplicate an entry to make that lane more common
  (two ABOVEs = overheads twice as likely); delete one to retire it.
  `head_offset` (keep between −8 and −20 or head shots whiff/stop reading as duckable).
- `spawn_radius`, `despawn_radius` (despawn must stay well above spawn).

### Attack designs — `resources/attacks/*.tres`
Three placeholders to replace with your own: `zippy` (fast/small), `chonker` (slow/fat),
`spiker` (red, UNparryable). Per attack: `speed`, `telegraph_time` (never below ~0.4s),
`damage`, `parryable`, `color`, `size`, `deflect_speed_multiplier`, pulse look.
New attack = new .tres file. Never code.

## Your flair spots
Grep for `## FLAIR:` — empty hooks meant for you: `_on_dodge_start`, `_on_parry_start`,
`_on_parry_success`, `_on_hit` (player.gd), the stamina arc `_draw` (stamina_arc.gd),
the telegraph pulse (projectile.gd), the ramp curve (spawner.gd).

## The workflow
Phase 1 (done) → **YOU: play + tune + note what's fun** → Phase 2 (upgrades, timer
multiplier, juice, torch) → **YOU: author attacks/upgrades** → Phase 3 (art, music, polish).
Tuning numbers live in `docs/04-reaction-game-guide.md` (researched values, not vibes).
When a feel problem comes up: reach for a knob first, code second.
```

One correction to note: this file describes the current build — if you tune defaults in the Inspector, the doc won't auto-update, so treat the numbers here as starting points, not truth.