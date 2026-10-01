extends Resource
class_name AbilityData

## AbilityData: one hero ability (passive or active). The numbers live in
## resources/abilities/*.tres; HeroAbilities / Player / FloorManager apply them.

enum Effect {
	## Passives
	DAMAGE_REDUCTION_PCT,   ## value = fraction of incoming damage ignored (0.2 = -20 %)
	NEXUS_PROXIMITY_REDUCTION,  ## value = max reduction at the Nexo, fading to 0 at `radius` px
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


func is_active() -> bool:
	return effect >= Effect.TEAM_ATTACK_BUFF
