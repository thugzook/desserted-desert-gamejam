# Scope & Antipatterns

What we deliberately **won't** build, and the week's schedule. When a future session (or you at 2am) is tempted by one of these, this doc is the veto.

## 1. Antipattern table

| Tempting pattern | Where you saw it | Why it's overkill here | Do instead |
|---|---|---|---|
| Node-based state machine | topdown template `scripts/state_machine/` (154 + 94 lines + 25 state files) | Built for many entities/NPCs/props; our 8 states fit one readable file | enum + `match` in `player.gd` (cookbook 1) |
| Threaded SceneManager with transitions | topdown `scripts/autoloads/SceneManager.gd` (~257 lines) | We have ~1 scene; loading is instant | `get_tree().reload_current_scene()`; if a menu scene ever exists, `change_scene_to_file()` |
| Save system with save-groups + duck-typed `get_data/receive_data` | topdown `DataManager.gd` + `SaveFileManager.gd` | Nothing to save but one number | One `ConfigFile` for high score (cookbook 8) |
| Inventory & item resources | topdown `components/inventory.gd`, `items/` | No items in this game | — |
| Dialogue system | topdown `addons/dialogue_manager` | No dialogue; addon adds concept load | Hardcoded `Label` text if the game ever "speaks" |
| Navigation / tilemaps / pathfinding | topdown `tilemap_navigation.gd`, tilesets | There is no world to navigate — attacks fly in straight lines | Tweens |
| CharacterBody2D + gravity | platformer `player.gd` | The player never moves through space; "jump" is a state + animation | `Area2D` player (cookbook 1) |
| Object pooling for projectiles | general internet advice | GDScript is ref-counted (no GC spikes); pooling pays off at bullet-hell scale, not our <20 live attacks | `instantiate()` + `queue_free()` — measured cost is microseconds |
| Localization | topdown `local/` | Jam judges read one language | Hardcode strings |
| Settings menu | topdown `scenes/menus/settings_menu` | Nobody adjusts settings in a 2-minute jam session | At most one master-volume slider, else nothing |
| Custom sound manager | common tutorial-land invention | Indirection with no payoff at 10 sounds | `AudioStreamPlayer` per sound (cookbook 10) |
| Health as a framework | topdown `health_controller.gd` (state hooks, PackedScene bars) | One entity has HP | inline `hp` int (cookbook 4A) |

The meta-rule: **the topdown template solves a genre we're not making.** We took its *ideas* (signal bus, resources-as-data, hurtbox-state interaction, exported tunables) and left its *machinery*.

## 2. The week (jam schedule)

Consensus jam wisdom: core loop playable day 1, finish at ~75% time, polish the rest. ("If you don't have a playable game by hour 20, you've overscoped.")

| Day | Goal | Definition of done |
|---|---|---|
| **1** | Gray-box core loop | One attack type flies at a gray rectangle; duck dodges it; getting hit loses HP; dying shows restart. **Playable end-to-end.** |
| **2** | All 5 actions + data pipeline | All states in; `AttackData`/`WaveData` `.tres` authoring works; 5 placeholder attack types |
| **3** | Content + teaching ramp | Wave sequence per doc 04 §6; score + HUD; dessert/desert art starts replacing gray boxes |
| **4** | Juice + audio | Hitstop, shake, flash, per-attack telegraph SFX, music. (Highest rating-per-hour day — don't skip.) |
| **5** | External playtest | Someone else plays; re-tune all windows more generously (doc 04 §7 checklist) |
| **6** | Polish + export | Title/game-over screens, web export uploaded and *tested in a browser* |
| **7** | Buffer | Jam page, screenshots, slack for everything that slipped |

Export note: do a throwaway **web export on day 2**, not day 6 — export surprises (audio, input focus) are the classic jam-killer.

## 3. Cut list (what dies first when behind)

In order — cut from the top:

1. Parry fail-soft / anti-mash (doc 04 §3) — stretch by definition
2. 5th attack type (ship 4… or 3)
3. Music (keep SFX — they're gameplay, doc 04 §2)
4. Title screen (boot straight into the game)
5. High-score persistence (session score only)
6. Combo/multiplier scoring
7. **Never cut:** the teaching waves, the input buffer, restart-on-death. These are the difference between "neat idea" and "unfair mess."

## 4. Scope smells (catch yourself)

- Writing a class the game has one of → inline it.
- A tweak requires editing 3 files → the tunable belongs in an `@export` or a `.tres`.
- "While I'm here I'll also..." → that's scope creep wearing a helpful mask; write it on the stretch list instead.
- Building a system before its second use exists → YAGNI; the second use usually never comes in a jam.
