# Game Brief — "Desserted Desert Dessert" (v2)

> **Status: USER SPEC (2026-07-24).** This version was written from the user's design
> brief and **supersedes the v1 draft entirely** where they conflict. Sections marked
> **[user spec]** restate the user's intent — do not reinterpret them. Sections marked
> **[interpretation]** are AI integration notes the user has not yet confirmed.
> Future AI sessions: the user's edits here always win.

## Design pillars [user spec]

1. **Go faster.**
2. **Power fantasy.**
3. **Player agency** — you make the game easier or harder based on your choices.

Inspirations: Temple Run, RUN (the flash game), Vampire Survivors — any game that encourages you to make choices that influence the way you play, possibly going faster as well. Race the Sun and Boson X are good examples.

Art & sound: **TBD.** Simple pixel art for now, or blocky shapes we can modify later.

## Main aim [user spec]

Dodge + parry attacks and go faster, trying to live the longest using the **timer at the top**. Upgrades help make dodging easier or make time move faster. It's a pure risk-vs-reward game — **how close can you fly towards the sun?**

## Core loop [user spec]

```
Dodge/Parry attacks → Manage stamina → Choose upgrades to get your score higher
       → Dodge/Parry attacks → …
```

## Enablers & blockers [user spec]

| | Toward the goal | Against the goal |
|---|---|---|
| **Active** | 4-direction dodge (arrow keys / WASD) · high-risk-high-reward parry that gives stamina back on successful parry | Projectiles |
| **Passive** | Stamina recovery over time · any buffs earned during the run | Stamina (resource) management · reaction time |

## High-level features [user spec]

- **A timer** — the survival clock at the top of the screen; your score is linked to your time.
- **A timer multiplier** — score is linked to time, so to get a longer time you need to speed time up, **which makes the game harder**. (Fly closer to the sun.)
- **Stamina system** — actions are linked to stamina: dodging costs stamina; successful parries return stamina.
- **4-direction dodge, collision-based** — ⚠️ **design change from v1:** dodge resolution is **NOT tied to attack patterns** (no "this attack requires DUCK" matching). Whether you're hit is decided by **character collision** — you physically move out of (or into) a projectile's path. Rationale: flexibility — if the player jumps into an unavoidable mix of projectiles, they must be able to **parry while in the air**.
- **Items at critical points in the run:**
  - some **beneficial but mild** (restore health, increase max stamina)
  - some **risky** (recover stamina 50% faster, but the game gets 25% faster)
  - some **cursed** (for later)

## UI framework — from `docs/UI-mock.jpg` [user spec, notes are interpretation]

The mock shows, checked against the intent brief:

- **Timer top-center** in `00:00:00` format, with the **timer multiplier** (e.g. `x1.5`) displayed just beside it — matches "live the longest using the timer at the top" + the multiplier feature.
- **Life total** as hearts (3 in the mock) directly under the timer — confirms health exists alongside stamina. **[interpretation]** Getting hit costs a heart, not stamina (spec ties stamina to *actions*; "restore health" items imply a separate pool).
- **Player character** — a blocky placeholder (matches "blocky shapes for now") standing on a **ground line at bottom-center** of the play area, *not* floating mid-screen. **[interpretation]** With a ground plane, the up-dodge reads as a jump — consistent with the "parry while in the air" scenario.
- **Projectiles** converging from multiple directions (top, left, right in the mock) — supports collision-based dodging. **[interpretation]** No lane system implied by the mock.
- **Stamina as a "Deadlock"-style bar**: segmented radial pips arcing around the player character, not a corner HUD bar. **[interpretation]** Good call for a reaction game — stamina stays in the same foveal zone as the dodging.

## Phases [user spec, sizing rationale from user: "I don't want to make too much in one run because I won't be able to maintain it"]

**Rule: one phase per build run.** Each phase ends with a game that runs, is understandable, and could ship as-is. Do not start the next phase in the same session; the user reviews between phases.

### Phase 1 — base prototype ("the essential is timer, dodge, parry and projectiles")

1. **Timer** — `00:00:00` survival clock, top center. It IS the score (no multiplier yet — fixed ×1.0).
2. **Health** — 3 hearts; projectile hit = −1 heart; 0 = game over → restart.
3. **4-direction dodge** — dash-and-return, SNAPPY: dodge left = move quickly to the "left" position, hang briefly, return quickly to home. Costs stamina.
4. **Parry** — instant reward on success (stamina back); animation lock on failure (exposed, possibly hit). Usable mid-dodge.
5. **Stamina system** — dodge costs it, successful parry refunds it, regenerates over time. Radial pips around the character.
6. **Projectiles** — plain rectangles (maybe a "trace" animation for flair), collision-based hits, simple repeating spawn pattern.
7. **High-score persistence** (shipped with the prototype — trivial via ConfigFile).

**Done when:** you can play a full run — survive, dodge, parry, die, see your time, restart — and every number is tweakable in the Inspector.

### Phase 2 — the risk-vs-reward layer

- **Upgrade system** — items at critical points; mild tier (restore health, +max stamina) and risky tier (+50% stamina regen but +25% game speed). Cadence (time-based vs event-based) gets decided at the start of this phase — deliberately deferred.
- **Timer multiplier** — appears next to the timer; rises **through upgrades only** (no direct control). This is where "fly closer to the sun" becomes real.
- **Satisfying parry/movement** — game feel pass: hitstop, shake, SFX, animation snap (docs/03 §9).
- **Light system** — e.g. a torch that narrows your view (per user: phase 2 stuff).

**Done when:** a run's difficulty is meaningfully shaped by the player's upgrade choices.

### Phase 3 — stretch / polish

- Cursed items
- Music
- Animations / character design (replace the rectangles)
- Controls-remap menu (defaults ship in Phase 1; the menu is Phase 3 plumbing)
- Anything cut from earlier phases

## Framework impact [interpretation — to reconcile in docs/02 & 03 next session]

The v1 framework docs were written for a lane/state-matching game. What this spec changes:

| v1 (docs/02–03 as written) | v2 (this spec) |
|---|---|
| States DUCK/JUMP/SLIDE_LEFT/SLIDE_RIGHT; `STATE_BEATS_DODGE` matching in `resolve_attack()` | **Delete dodge-type matching.** Player has a position + hurtbox; dodges are short directional moves (up/down/left/right); hit = hurtbox overlap, dodge = simply not being there |
| Actions are committed states; inputs only from IDLE | **Parry must be usable during a dodge** (e.g. airborne). Parry becomes an overlay action, not an exclusive state |
| `AttackData.dodge_type` drives resolution | `dodge_type` becomes (at most) a **spawn-direction/aim hint**; resolution is pure collision |
| Win = survive authored waves | **Endless survival; score = timer value.** Replaced by the Spawner's continuous ramp (`start_interval` → `min_interval` over `ramp_seconds`); authored patterns are a Phase 3 idea, per docs/04 §5 |
| No resource systems | **Stamina** (dodge costs, successful parry refunds, regen over time) + **timer multiplier** + **upgrade/item choices** |
| Player fixed at screen center | Per the mock: player on a **ground line at bottom-center**; up-dodge = a jump arc (still animation/tween-driven — the "no physics gravity" invariant can hold) |

Still valid and unchanged: signal bus + 2 autoloads, Resources for attack/wave/item data (items are a natural third resource type), enum+match state machine (with a reshaped state set), input buffer + player-favoring leniency, telegraph/timing numbers (docs/04), juice pack, restart flow, scope discipline (docs/05).

## Resolved decisions [user spec, answered 2026-07-24]

| Question | User's answer |
|---|---|
| Parry cost on whiff | No stamina cost — the risk is **recovery/exposure time**. Parries are **instant reward on success, animation lock on failure** (possibly get hit during the lock). |
| Timer multiplier control | **Upgrade only.** No direct player control. |
| Dodge feel | **Dash-and-return. It should feel SNAPPY.** Dodge left = character moves quickly to the "left" position in space, hangs there a bit, then returns quickly to home. |
| Upgrade cadence | Not defined yet — **deliberately deferred to Phase 2**. "The essential is timer, dodge, parry and projectiles for now." |
| Controls | Default **A/S/D + Space for movement, J for parry**; a menu to change controls comes later (Phase 3). |
| Light system | The torch **narrows view** (example). Phase 2. |
| Projectile art | **Plain rectangles**, maybe a "trace" animation for light flair. |

## Still open

- [ ] **[interpretation to confirm]** Exact dodge mapping for "ASD + Space": reading it as **A = left, D = right, S = down, Space = up/jump** (W unused). Correct?
- [ ] Dessert/desert theme skin — parked; rectangles until Phase 3.
- [ ] Jam deadline date/time (for CLAUDE.md).
