# Reaction Game Design Guide

Genre knowledge the reference repos don't have: how to make a duck/jump/slide/parry game feel *fair and tight* instead of random and cheap. Concrete numbers throughout — they're the starting values for our `@export` vars.

## 1. The reaction-time budget

Physiology sets a hard floor on how fast anyone can respond:

- Simple visual reaction (see it → press one known button): median **~273ms** (Human Benchmark dataset).
- Audio is **~30–50ms faster** than visual — a reason to give every attack a sound (§2).
- **Our game is harder than that**: the player must *identify* which of 5 responses fits, which pushes response time to **320–530ms** in multi-choice studies (arXiv 2305.17180).
- Design formula (GDKeys "Anatomy of an Attack"): minimum telegraph = reaction time + the player action's own startup + a difficulty buffer. And that minimum is a *hard-mode floor*.

**Our defaults:** telegraph + travel ≥ **600–800ms** early game; never below **~400ms** even at max difficulty. (In `AttackData`: `telegraph_time 0.6` + `travel_time 0.5` early; floor around `0.2 + 0.2` late.)

Sources: https://humanbenchmark.com/tests/reactiontime/statistics · https://gdkeys.com/keys-to-combat-design-1-anatomy-of-an-attack/ · https://arxiv.org/pdf/2305.17180

## 2. Telegraphing: every attack answers a question

Mike Stout (Insomniac): an attack is a *question* the game asks; the telegraph is how the player hears it. "If players don't understand the questions they are being asked, they actually cannot play your game."

Rules we follow:

1. **Every attack type gets one unmistakable identity**: a distinct silhouette/approach angle + a distinct color + a distinct sound. Never reuse a cue across types.
2. **The sound starts at wind-up**, not impact — it's the fastest channel (§1). In our code, `attack.gd` plays `telegraph_sfx` the moment it spawns.
3. **Same attack, same telegraph, every time.** Consistency is what turns reacting into learning.
4. **Attack anatomy = anticipation → active → recovery.** Make anticipation *long and exaggerated* (Cuphead's cartoon wind-ups are best-in-class); make the active phase fast and **constant-speed** — easing on the travel makes impact timing unreadable, which is why our projectile tween uses `TRANS_LINEAR`.
5. Cheap color convention: one hue per required response (e.g. red glint = parryable, à la Sekiro's "perilous" flash).

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

**Our defaults:** `parry_active_window 0.15` (9 frames — tight-but-fair). Dodges are **state-based, not frame-perfect**: if you're ducked when the high attack passes, you're safe, period — the effective window is the whole `duck_duration` (~400ms). Jam players get one 2-minute session with zero practice: **err one tier more generous than feels right to you** — after a week of testing your own game, you are the worst possible difficulty judge.

Sources: https://sekiroshadowsdietwice.wiki.fextralife.com/Deflection · https://wiki.supercombo.gg/w/Street_Fighter_3:_3rd_Strike/System · https://cuphead.wiki.gg/wiki/Parry_Slap

## 4. Leniency: ties favor the player

Maddy Thorson on Celeste (canonical read — https://maddythorson.medium.com/celeste-forgiveness-31e4a40399f1): every timing/position check is "fudged a tiny bit in the player's favor... a big reason why Celeste can feel kind even though it's very difficult." Players never notice the individual fudges — they just say the controls feel *tight*. The asymmetry: players blame the *game* for unfair hits but credit *themselves* for narrow escapes. Leniency is free fun.

Our implementations:

- **Input buffer (120ms):** an action pressed slightly early fires the moment it legally can (cookbook pattern 2). Industry norm is 100–150ms.
- **Same-frame ties:** if an attack lands the exact tick a dodge starts, the dodge wins — our `resolve_attack()` checks dodge-before-hit deliberately.
- **Late grace (stretch):** accept a parry up to ~50ms *after* nominal impact (Celeste's coyote time is 5 frames of the same idea).
- Corroboration from Crypt of the NecroDancer: they shipped **double** their initial timing leeway, because "the times when you are least accurate are the times when you are most stressed."

Source: https://www.gamedeveloper.com/audio/game-design-deep-dive-finding-the-beat-in-i-crypt-of-the-necrodancer-i-

## 5. Difficulty ramping

- **Ramp one axis at a time** (ABA Games): pattern *complexity* first (longer waves, more mixed types), *speed* second — speed runs into the §1 physiological wall. Scaling both at once compounds non-linearly into impossible.
- **Sawtooth, not slope:** rising cycles with rest beats between waves (`WaveData.rest_after`). Players tolerate higher peaks when breathers follow.
- **Teach in isolation:** each new attack type appears *alone*, slow, 3–5 times, before it's ever mixed. (Punch-Out structure: each opponent is a learnable composition.)
- **Author on a beat grid:** Punch-Out is "a rhythm game without music"; Hi-Fi Rush attacks on the beat. Practical version for us: pick ~100 BPM (600ms/beat), make `gap` a multiple of the beat, `telegraph_time` = 1 beat. Patterns become learnable music, and wave `.tres` files become trivially authorable ("attack on beats 1, 2, 4...").

Sources: https://abagames.github.io/joys-of-small-game-development-en/difficulty/curve.html · https://www.gamedeveloper.com/design/difficulty-curves

## 6. Wave-authoring recipe

When filling `resources/waves/`:

1. Wave 1: one attack type × 4 reps, telegraph 0.8s, gap 2 beats.
2. One new type per wave, taught solo, then one "mix quiz" wave of the two.
3. After all 5 types are taught: mixed waves, shrink `gap` from 2 beats → 1 beat.
4. Only then shrink `telegraph_time`/`travel_time` (never below ~400ms total, §1).
5. `rest_after`: 2–4s normally; longer after a spike.
6. End every session by making something 20% easier than feels right (§3).

## 7. Playtest checklist (day 5–6)

Watch someone else play once, silently. Check:

- [ ] Did they understand which action beats which attack *without being told*? (If no → telegraph identity problem, §2.)
- [ ] Did they ever say "I pressed it!"? (If yes → widen buffer/windows, §4.)
- [ ] Did they die during the *teaching* waves? (If yes → slow wave 1–2 down.)
- [ ] Could they tell dodge from parry scoring? (If no → juice/HUD feedback gap.)
- [ ] Did they immediately hit restart when they died? (The real success metric.)
