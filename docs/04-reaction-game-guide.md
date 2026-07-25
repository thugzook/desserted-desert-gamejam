# Reaction Game Design Guide

Genre knowledge the reference repos don't have: how to make a dodge/parry game feel *fair and tight* instead of random and cheap. Our version of the genre is 4-direction dash-and-return plus a parry window (`docs/02` §4–5). Concrete numbers throughout — they're the starting values for our `@export` vars.

## 1. The reaction-time budget

Physiology sets a hard floor on how fast anyone can respond:

- Simple visual reaction (see it → press one known button): median **~273ms** (Human Benchmark dataset).
- Audio is **~30–50ms faster** than visual — a reason to give every attack a sound (§2).
- **Our game is harder than that**: the player has to *choose* — read the lane, recall its answer (sidestep overheads, jump body shots, duck head shots — `LANE_ANSWERS`), or parry instead. That's a multi-choice decision, not a single known button, and multi-choice studies put it at **320–530ms** (arXiv 2305.17180). The v3 direction rule makes this the game's core skill test, so these numbers are load-bearing: telegraphs must budget for *recognition + recall*, not just reflex.
- Design formula (GDKeys "Anatomy of an Attack"): minimum telegraph = reaction time + the player action's own startup + a difficulty buffer. And that minimum is a *hard-mode floor*.

**Our defaults:** the reaction budget is the telegraph plus the flight time from spawn to the player. Aim for ≥ **600–800ms** early game and **never below ~400ms** at any difficulty. In `ProjectileData`: `telegraph_time` **0.6–0.9** early, and never below **~0.4** (§6, rule 5) — that floor is physiological, not a difficulty setting.

Sources: https://humanbenchmark.com/tests/reactiontime/statistics · https://gdkeys.com/keys-to-combat-design-1-anatomy-of-an-attack/ · https://arxiv.org/pdf/2305.17180

## 2. Telegraphing: every attack answers a question

Mike Stout (Insomniac): an attack is a *question* the game asks; the telegraph is how the player hears it. "If players don't understand the questions they are being asked, they actually cannot play your game."

Rules we follow:

1. **Every attack type gets one unmistakable identity**: a distinct silhouette/approach angle + a distinct color + a distinct sound. Never reuse a cue across types.
2. **Phase 1 telegraphs visually only.** A projectile sits still and blinks — `pulse_rate` and `pulse_min_alpha` on `ProjectileData` — while `color` and `size` carry the per-attack identity. That's the whole system until art exists.
3. **Per-attack SFX is the recommended Phase 2 upgrade.** Audio reaction is ~50ms faster than visual (§1), so a wind-up sound is the single cheapest way to buy the player reaction time. Start the sound at wind-up, not impact.
4. **Same attack, same telegraph, every time.** Consistency is what turns reacting into learning.
5. **Attack anatomy = anticipation → active → recovery.** Make anticipation *long and exaggerated* (Cuphead's cartoon wind-ups are best-in-class); make the active phase fast and **constant-speed** — acceleration on the travel makes impact timing unreadable. Our projectiles move at a flat `speed * delta` in `_physics_process` for exactly that reason: no easing curve to misjudge.
6. Cheap color convention: one hue per required response (e.g. red glint = parryable, à la Sekiro's "perilous" flash).

Sources: https://www.gamedeveloper.com/design/enemy-attacks-and-telegraphing · https://www.gamedeveloper.com/game-platforms/designing-for-difficulty-readability-in-arpgs

## 3. Timing windows: how tight is tight?

Known frame data, converted at 60fps (1 frame ≈ 16.7ms):

| Game | Window | ms | Feel |
|---|---|---|---|
| Cuphead parry (timing part) | 1–2 f | ~17–33 | brutal (huge hitboxes compensate) |
| SF6 Perfect Parry | 2 f | ~33 | expert |
| SF3 Third Strike parry | 10 f | ~167 | "hard but learnable," iconic |
| Sekiro deflect | 12 f | ~200 | generous by design |
| Dark Souls 3 roll i-frames | 13 f | ~217 | standard action dodge |

Taxonomy: **≤50ms = superhuman · 100–167ms = tight-but-fair · 200–250ms = generous · 300ms+ = beginner-friendly.**

Two Sekiro tricks worth stealing (both cheap):
- **Fail-soft:** a missed deflect degrades to a *block* (reduced damage), not a clean hit. Stretch goal for us: late parry against a parryable attack = "blocked" for half damage.
- **Anti-mash:** the window shrinks if you spam the button. Only add this if playtests show spam trivializes parrying.

**Our defaults:** `parry_window 0.15` (9 frames — tight-but-fair). Dodges are a **timed window, not frame-perfect**: the dodge is active for `dodge_out_time + dodge_hang_time + dodge_return_time` (~340ms at defaults — "generous" tier above, on purpose, because the direction rule already adds a read cost), and `dodge_hang_time` is the knob that widens it. A correctly-directed dodge anywhere in that window neutralizes the shot; a wrong direction fails no matter the timing. Jam players get one 2-minute session with zero practice: **err one tier more generous than feels right to you** — after a week of testing your own game, you are the worst possible difficulty judge.

Sources: https://sekiroshadowsdietwice.wiki.fextralife.com/Deflection · https://wiki.supercombo.gg/w/Street_Fighter_3:_3rd_Strike/System · https://cuphead.wiki.gg/wiki/Parry_Slap

## 4. Leniency: ties favor the player

Maddy Thorson on Celeste (canonical read — https://maddythorson.medium.com/celeste-forgiveness-31e4a40399f1): every timing/position check is "fudged a tiny bit in the player's favor... a big reason why Celeste can feel kind even though it's very difficult." Players never notice the individual fudges — they just say the controls feel *tight*. The asymmetry: players blame the *game* for unfair hits but credit *themselves* for narrow escapes. Leniency is free fun.

Our implementations:

- **Input buffer (120ms):** an action pressed slightly early fires the moment it legally can (`input_buffer` on the Player). Industry norm is 100–150ms.
- **Parry beats damage:** `_resolve()` checks the parry window *before* it checks for a hit, so a parry landing on the same tick as the projectile resolves in your favor.
- **Mercy i-frames (900ms):** after any hit you're untouchable for `iframe_time`, so one dense cluster can't take all three hearts at once.
- **Late grace (stretch):** accept a parry up to ~50ms *after* nominal impact (Celeste's coyote time is 5 frames of the same idea).
- Corroboration from Crypt of the NecroDancer: they shipped **double** their initial timing leeway, because "the times when you are least accurate are the times when you are most stressed."

Source: https://www.gamedeveloper.com/audio/game-design-deep-dive-finding-the-beat-in-i-crypt-of-the-necrodancer-i-

## 5. Difficulty ramping

- **Ramp one axis at a time** (ABA Games): *density* first (shorter `min_interval`, more mixed types), *speed* second — projectile speed runs into the §1 physiological wall. Scaling both at once compounds non-linearly into impossible.
- **Sawtooth, not slope:** rising cycles with breathers between them. Players tolerate higher peaks when a rest follows. Our spawner ramps on a straight line instead, so the cheap approximation is a gentle `ramp_seconds` — real rest beats need authored patterns (below).
- **"Teaching" without authored waves:** we spawn randomly, so a new type can't be introduced alone. The two levers that do the teaching are a **generous `start_interval`** (1.6s+, so the first ~15 seconds are survivable while you learn the controls) and **visually distinct attacks** (`color` + `size`, §2) so types stay tellable apart once they mix.
- **Beat grids and authored patterns are a Phase 3 idea, if ever.** Punch-Out is "a rhythm game without music"; Hi-Fi Rush attacks on the beat, and that's genuinely more learnable than randomness. But it means an authoring format and content work we cut on purpose (`docs/05` §1). If it ever comes back: ~100 BPM (600ms/beat), spawn interval a multiple of the beat, `telegraph_time` = 1 beat.

Sources: https://abagames.github.io/joys-of-small-game-development-en/difficulty/curve.html · https://www.gamedeveloper.com/design/difficulty-curves

## 6. Tuning recipe (endless ramp, not authored waves)

Phase 1 spawns randomly from your attack list and shrinks the interval over time, so difficulty is three Spawner numbers plus your attack designs:

1. **Design attacks that read differently.** Each `.tres` gets its own `color` and `size` — that's the whole identity system until art exists (§2).
2. **Set `start_interval` generously** (1.6s+) so the first ~15 seconds teach the game by being survivable.
3. **Set `min_interval` by playtest**, not by instinct — it's the hardest the game ever gets.
4. **Stretch `ramp_seconds`** if players die before they've learned; shorten it if the game gets boring before it gets hard.
5. **Never take `telegraph_time` below ~0.4s** on any attack (§1) — that's the physiological floor.
6. End every session by making something 20% easier than feels right (§3).

## 7. Playtest checklist (day 5–6)

Watch someone else play once, silently. Check:

- [ ] Could they tell which direction clears each attack, at a glance? (If no → telegraph identity problem, §2.)
- [ ] Did they ever say "I pressed it!"? (If yes → widen buffer/windows, §4.)
- [ ] Did they die in the first 15 seconds? (If yes → raise `start_interval`.)
- [ ] Could they tell dodge from parry scoring? (If no → juice/HUD feedback gap.)
- [ ] Did they immediately hit restart when they died? (The real success metric.)
