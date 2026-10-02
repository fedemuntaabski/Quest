extends Resource
class_name TargetProfile

## TargetProfile: what an enemy goes for, as data. `rules` are priorities (the
## first valid one wins); when none is, `fallback` decides. EnemyType.target_profile
## points at one; when it is null EnemyType.get_target_profile() derives one from
## the legacy role/behavior so older .tres keep working (see derive()).

enum Fallback { NEAREST_HERO_ZONE, NEXO, HOLD }

@export var id: StringName = &""
## Shown by the bestiary.
@export var display_name: String = ""
@export_multiline var description: String = ""
## ORDER = priority.
@export var rules: Array[TargetRule] = []
## A hero that hits it (or stands within TargetSelector.BLOCK_RANGE) provokes it:
## for `retaliate_sec` it ignores `rules` and goes for the nearest hero.
@export var retaliate: bool = false
@export var retaliate_sec: float = 3.0
## Seconds between target re-evaluations (the enemy's AiTimer). 0 = the
## behavior's ai_interval in Enemy.VARIANT_CONFIG.
@export var reeval_sec: float = 0.0
## Hits an active module of any kind in a room it walks into (today's behavior of
## every non-raider), on top of whatever its rules target. false = ignores modules
## it was not sent for (assassins).
@export var hits_modules_en_route: bool = true
## A hero is dropped only beyond aggro_range * this (anti-flicker).
@export var drop_range_mult: float = 1.25
@export var fallback: Fallback = Fallback.NEAREST_HERO_ZONE

## Lazily built, shared by every enemy without an explicit profile.
static var _derived: Dictionary = {}


## The hero rules a provoked enemy follows: the Hunter's.
static func hunter_rules() -> Array[TargetRule]:
	return [TargetRule.make(TargetRule.Type.HERO_NEAREST, -1.0), TargetRule.make(TargetRule.Type.HERO_NEAREST, 0.0)]


## Legacy mapping: RAIDER role -> siege, Sapper behavior (1) -> saboteur, else hunter.
static func derive(role: int, behavior: int) -> TargetProfile:
	var key := "siege" if role == EnemyType.Role.RAIDER else ("saboteur" if behavior == 1 else "hunter")
	if not _derived.has(key):
		var profile := TargetProfile.new()
		profile.id = StringName(key)
		match key:
			"siege":
				profile.rules = [TargetRule.make(TargetRule.Type.NEXO)]
				profile.retaliate = true
			"saboteur":
				var rules_list: Array[TargetRule] = [TargetRule.make(TargetRule.Type.MODULE_ANY)]
				rules_list.append_array(hunter_rules())
				profile.rules = rules_list
			_:
				profile.rules = hunter_rules()
		_derived[key] = profile
	return _derived[key]


## True when its first priority is the Nexo (a raider).
func targets_nexo_first() -> bool:
	return not rules.is_empty() and rules[0].type == TargetRule.Type.NEXO
