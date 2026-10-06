extends Resource
class_name AbilityData

## AbilityData: one hero ability (passive or active). The numbers live in
## resources/abilities/*.tres; HeroAbilities / Player / FloorManager apply them.

enum Effect {
	## Passives
	DAMAGE_REDUCTION_PCT,   ## value = fraction of incoming damage ignored (0.2 = -20 %)
	NEXO_PROXIMITY_REDUCTION,  ## value = max reduction at the Nexo, fading to 0 at `radius` px
	SCIENCE_ON_DISCOVERY,   ## value = Ciencia gained when a new room is discovered
	DUST_ON_DISCOVERY,      ## value = Polvo gained when a new room is discovered
	## Actives (cooldown + duration)
	TEAM_ATTACK_BUFF,       ## allies in the caster's room: attack damage x(1 + value)
	MODULE_OVERCHARGE,      ## turrets in the caster's room: damage x(1 + value); generators pay one extra tick
	BURST_STRIKE,           ## every enemy in the caster's attack range takes attack damage x value
	TEAM_SHIELD,            ## all living heroes take (1 - value) of the damage
}

@export var id: String = ""
@export var effect: Effect = Effect.DAMAGE_REDUCTION_PCT
@export var value: float = 0.0
@export var duration: float = 0.0
@export var cooldown: float = 0.0
@export var radius: float = 0.0
## VfxManager effect id played on use (actives).
@export var vfx: StringName = &""

@export_group("UI")
## Shown in the hero sheet, the portrait button tooltip and hero select (heroes-9).
@export var display_name: String = ""
## Template with the real numbers filled by HeroAbilities.describe(): {value},
## {value_pct} (value x100, %), {duration}, {cooldown}, {radius} (perks included).
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_group("")


func is_active() -> bool:
	return effect >= Effect.TEAM_ATTACK_BUFF


## `description` with the placeholders replaced (raw numbers, no perks).
## HeroAbilities.describe() passes the hero's effective numbers instead.
func format_description(p_value: float = value, p_duration: float = duration, p_cooldown: float = cooldown, p_radius: float = radius) -> String:
	return description.format({
		"value": _num(p_value),
		"value_pct": _num(p_value * 100.0),
		"duration": _num(p_duration),
		"cooldown": _num(p_cooldown),
		"radius": _num(p_radius),
	})


static func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
