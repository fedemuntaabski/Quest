extends Resource
class_name AbilityData

## AbilityData: one hero ability (passive or active). The numbers live in
## resources/abilities/*.tres; HeroAbilities / Player / FloorManager apply them.

enum Effect {
	## Passives
	DAMAGE_REDUCTION_PCT,   ## value = fraction of incoming damage ignored (0.2 = -20 %)
	RELIC_PROXIMITY_REDUCTION,  ## value = max reduction at the Relic, fading to 0 at `radius` px
	LORE_ON_DISCOVERY,   ## value = Saber gained when a new room is discovered
	EMBERS_ON_DISCOVERY,      ## value = Brasas gained when a new room is discovered
	## Actives (cooldown + duration)
	TEAM_ATTACK_BUFF,       ## allies in the caster's room: attack damage x(1 + value)
	BUILDING_BLESSING,      ## defenses in the caster's room: damage x(1 + value); workshops pay one extra tick
	BURST_STRIKE,           ## every enemy in the caster's attack range takes attack damage x value
	TEAM_SHIELD,            ## all living heroes take (1 - value) of the damage
	## personajes-46 (appended: the .tres store the int)
	ALLY_REGEN,             ## passive: every `cooldown` s the living heroes in her room heal `value` HP
	IRON_ON_KILL,           ## passive: `value` Hierro per enemy this hero finishes off
	TEAM_HEAL,              ## active: the living heroes in the caster's room heal `value` HP at once
	SNARE,                  ## active: enemies in the caster's attack range are slowed for `duration` s
}

const ACTIVE_EFFECTS: Array[Effect] = [Effect.TEAM_ATTACK_BUFF, Effect.BUILDING_BLESSING, Effect.BURST_STRIKE, Effect.TEAM_SHIELD, Effect.TEAM_HEAL, Effect.SNARE]

@export var id: String = ""
@export var effect: Effect = Effect.DAMAGE_REDUCTION_PCT
@export var value: float = 0.0
@export var duration: float = 0.0
@export var cooldown: float = 0.0
@export var radius: float = 0.0
## Passives only (juego-36, Mente Analítica): fraction off every research cost while the
## hero stands (0.1 = -10 %). Read through ResourceManager.research_cost().
@export var research_discount: float = 0.0
## VfxManager effect id played on use (actives).
@export var vfx: StringName = &""

@export_group("UI")
## Shown in the hero sheet, the portrait button tooltip and hero select (heroes-9).
@export var display_name: String = ""
## Template with the real numbers filled by HeroAbilities.describe(): {value},
## {value_pct} (value x100, %), {duration}, {cooldown}, {radius} (perks included),
## {radius_cells} (radius in map cells, ArtConfig.CELL_PX), {discount_pct} (research_discount x100).
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_group("")


func is_active() -> bool:
	return effect in ACTIVE_EFFECTS


## `description` with the placeholders replaced (raw numbers, no perks).
## HeroAbilities.describe() passes the hero's effective numbers instead.
func format_description(p_value: float = value, p_duration: float = duration, p_cooldown: float = cooldown, p_radius: float = radius) -> String:
	return description.format({
		"value": _num(p_value),
		"value_pct": _num(p_value * 100.0),
		"duration": _num(p_duration),
		"cooldown": _num(p_cooldown),
		"radius": _num(p_radius),
		"radius_cells": _num(p_radius / ArtConfig.CELL_PX),
		"discount_pct": _num(research_discount * 100.0),
	})


static func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
