extends Node
## Global signal bus. Emit here when something game-wide happened; connect here to react.
## Rule: only CROSS-SYSTEM news belongs here. A node talking to its own child calls it directly.

@warning_ignore_start("unused_signal")
signal player_hit(hp_left: int)
signal player_died
signal parried(projectile)
signal dodged(direction: Vector2)
signal projectile_dodged(projectile)                   ## A shot was cleanly dodged (right lane, right time).
signal dodge_failed                                    ## Not enough stamina — cue a UI flash.
signal stamina_changed(current: float, max_value: float)
signal run_started
signal run_ended(time_survived: float)
@warning_ignore_restore("unused_signal")
