# Scope & Antipatterns

What we deliberately **won't** build, and the week's schedule. When a future session (or you at 2am) is tempted by one of these, this doc is the veto.

## 1. Antipattern table

| Tempting pattern | Where you saw it | Why it's overkill here | Do instead |
|---|---|---|---|
| Node-based state machine | topdown template `scripts/state_machine/` (154 + 94 lines + 25 state files) | Built for many entities/NPCs/props; our player needs 4 movement states | `enum State { HOME, DODGING, HIT, DEAD }` + two timers in `player.gd` |
| Attack-type ↔ player-state matching | the v1 plan for this game | Can't answer "what if I jump into an unavoidable mix?"; forces every attack into a category | Collision decides it — the hurtbox moves, so dodging needs no code at all |
| Hand-authored wave sequences (`WaveData`) | the v1 plan for this game | Endless survival ramps continuously; authored sets are content work we don't have time for | Spawner ramp: `start_interval` → `min_interval` over `ramp_seconds` |
| Threaded SceneManager with transitions | topdown `scripts/autoloads/SceneManager.gd` (~257 lines) | We have ~1 scene; loading is instant | `get_tree().reload_current_scene()`; if a menu scene ever exists, `change_scene_to_file()` |
| Save system with save-groups + duck-typed `get_data/receive_data` | topdown `DataManager.gd` + `SaveFileManager.gd` | Nothing to save but one number | One `ConfigFile` for high score (cookbook §2, in `Game`) |
| Inventory & item resources | topdown `components/inventory.gd`, `items/` | No items in this game | — |
| Dialogue system | topdown `addons/dialogue_manager` | No dialogue; addon adds concept load | Hardcoded `Label` text if the game ever "speaks" |
| Navigation / tilemaps / pathfinding | topdown `tilemap_navigation.gd`, tilesets | There is no world to navigate — attacks fly in straight lines | Tweens |
| CharacterBody2D + gravity | platformer `player.gd` | The player moves, but on a fixed out-and-back path — there's nothing to simulate, collide against, or fall onto | `Area2D` + a Tween (cookbook 3) |
| Object pooling for projectiles | general internet advice | GDScript is ref-counted (no GC spikes); pooling pays off at bullet-hell scale, not our <20 live attacks | `instantiate()` + `queue_free()` — measured cost is microseconds |
| Localization | topdown `local/` | Jam judges read one language | Hardcode strings |
| Settings menu | topdown `scenes/menus/settings_menu` | Nobody adjusts settings in a 2-minute jam session | At most one master-volume slider, else nothing |
| Custom sound manager | common tutorial-land invention | Indirection with no payoff at 10 sounds | `AudioStreamPlayer` per sound. Audio is Phase 2 — grab the free-asset links in cookbook §10 when you get there. |
| Health as a framework | topdown `health_controller.gd` (state hooks, PackedScene bars) | One entity has HP | inline `hp` int on the player (cookbook 3) |

The meta-rule: **the topdown template solves a genre we're not making.** We took its *ideas* (signal bus, resources-as-data, hitbox/hurtbox pairing, exported tunables) and left its *machinery*. Note the half we specifically did **not** take: its hurtboxes toggle on and off with entity *state*, which is the attack-vs-state matching we rejected in row 2.

## 2. The week (jam schedule)

Consensus jam wisdom: core loop playable day 1, finish at ~75% time, polish the rest. ("If you don't have a playable game by hour 20, you've overscoped.")

Mapped to the three phases (`docs/02` §1). The **you** rows are the handoffs — don't let a build session skip past one.

| Day | Who | Goal | Done when |
|---|---|---|---|
| **1** | AI | **Phase 1** — the prototype | Timer, health, 4-dir dodge, parry, stamina, projectiles, HUD. F5 → play → die → restart. |
| **1–2** | **You** | Tune the feel | Dodge/parry/stamina numbers feel right; you can say which parts are fun |
| **2–3** | AI | **Phase 2** — risk/reward | Upgrades, timer multiplier, juice pass, torch |
| **3–4** | **You** | Author content | Design the actual attack `.tres` files and upgrade set; re-tune the ramp |
| **4–5** | AI + you | **Phase 3** — polish | Art, music, animations, cursed items, controls menu |
| **5** | **You** | External playtest | Someone else plays; re-tune windows *more generously* (doc 04 §7) |
| **6** | AI + you | Export | Web export uploaded and *tested in a browser* |
| **7** | — | Buffer | Jam page, screenshots, slack for what slipped |

Export note: do a throwaway **web export on day 2**, not day 6 — export surprises (audio, input focus) are the classic jam-killer.

## 3. Cut list (what dies first when behind)

In order — cut from the top:

1. Cursed items (Phase 3 by definition)
2. Torch / light system
3. Music (keep SFX — they're gameplay, doc 04 §2)
4. Controls-remap menu (defaults ship in Phase 1)
5. Title screen (boot straight into the game)
6. ~~High-score persistence~~ — **already done, don't cut.** It ships in Phase 1 (`Game` + one `ConfigFile`, cookbook §2); removing it now would be *more* work than keeping it.
7. Upgrade system — **this is the last thing to cut.** Without it the game has no risk/reward loop and no player agency; it's just a dodging test.
8. **Never cut:** the input buffer, mercy i-frames, restart-on-death, and a generous `start_interval`. These are the difference between "neat idea" and "unfair mess."

## 4. Scope smells (catch yourself)

- Writing a class the game has one of → inline it.
- A tweak requires editing 3 files → the tunable belongs in an `@export` or a `.tres`.
- "While I'm here I'll also..." → that's scope creep wearing a helpful mask; write it on the stretch list instead.
- Building a system before its second use exists → YAGNI; the second use usually never comes in a jam.
