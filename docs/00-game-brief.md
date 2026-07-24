# Game Brief — "Desserted Desert Dessert"

> **Status: DRAFT.** The mechanics sections are settled framework; the creative sections
> (theme, names, art direction) are placeholders for you to edit or replace with your
> project plan. Future AI sessions: treat the *user's* edits here as the source of truth.

## Concept (one sentence)

A lone snack stands in the desert while waves of desserts fly at it — duck, jump, slide, and parry to survive the sugar rush.

## Theme interpretation (placeholder — make it yours)

Ideas to riff on: you're the last dessert *deserted* in the desert; enemy projectiles are donuts (duck through the hole?), baguettes, cactus-cupcakes, rolling cinnamon buns, sandstorm sprinkles. A parry could be a spatula swat. Wave titles as puns ("Just Deserts", "Pie Noon" — high noon showdown framing fits the fixed-position duel).

## Core loop

```
attack telegraphed (sound + wind-up)
   → player picks a response (duck / jump / slide_left / slide_right / parry)
   → resolution: dodged (+10) | parried (+25) | hit (−1 HP)
   → next attack; waves ramp per docs/04 §5
```

Session length target: 2–3 minutes to game over for a first-time player.

## Player verbs

Duck, Jump, Slide Left, Slide Right, Parry. (Full state machine: `docs/02` §3.)

## Win/lose

- **Lose:** HP (3) reaches 0 → game over → score + high score → instant restart.
- **Win (MVP):** survive all authored waves → victory screen + score. Endless mode is stretch.

## MVP cutline (ships by day 5)

- 4–5 attack types with distinct telegraphs (sound + color + angle)
- Teaching wave sequence (each type solo before mixing — docs/04 §6)
- Score, HP hearts, game over, restart, high score
- Hitstop/shake/flash juice + per-attack SFX
- Web export that runs in a browser

## Stretch (in cut-priority order — see docs/05 §3)

1. Parry fail-soft (late parry = half damage block)
2. Boss pattern (long scripted wave with its own music)
3. Combo meter / score multiplier
4. Endless mode with procedural wave mixing
5. Practice mode (accessibility)

## Open questions for the user

- [ ] Final theme/art direction (what IS the player sprite?)
- [ ] Keyboard mapping preference (arrows? WASD + space/J/K?)
- [ ] Target: web build for the jam page, correct?
- [ ] Jam deadline date/time (to put in CLAUDE.md)
