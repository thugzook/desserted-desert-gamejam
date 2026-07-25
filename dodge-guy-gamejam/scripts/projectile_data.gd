class_name ProjectileData
extends Resource
## One attack type. Create via FileSystem → right-click resources/attacks/ →
## Create New → Resource → ProjectileData, then fill these in.
## A new attack is a new .tres file — never new code.

@export var display_name := "Attack"
## Pixels per second once it launches. 300 = readable, 700 = scary.
@export var speed := 420.0
## Seconds it sits still and visible before launching. This is the player's
## reaction budget — see docs/04 §1. Do not go below ~0.4.
@export var telegraph_time := 0.7
@export var damage := 1
## Can the parry window deflect it? Set false for attacks that must be dodged.
@export var parryable := true
## FLAIR: how the player tells this attack from the others, at a glance.
@export var color := Color(0.95, 0.85, 0.6)
@export var size := Vector2(56.0, 18.0)

@export_group("Dodge Payoff")
## How visible a successfully-dodged shot stays as it coasts through you.
## 0.25 = faint ghost. 0 = it disappears the instant you dodge it.
@export var ghost_alpha := 0.25

@export_group("Parry Payoff")
## How much faster a deflected shot flies back. Higher = a parry feels more violent.
@export var deflect_speed_multiplier := 2.0

@export_group("Telegraph Look")
## Seconds per half-blink while telegraphing. Lower = a more frantic flash.
@export var pulse_rate := 0.12
## How faint the blink gets. Lower = a harder, more obvious strobe.
@export var pulse_min_alpha := 0.35
