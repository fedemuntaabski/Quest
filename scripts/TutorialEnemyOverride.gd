extends RefCounted
class_name TutorialEnemyOverride

const TUTORIAL_CONFIG := {
	"hp": 1,
	"forced_miss_chance": 1,
	"base_damage": 0,
	"base_tint": Color(0.42, 1.0, 0.52, 1.0),
	"target_tint": Color(0.75, 1.0, 0.8, 1.0)
}

static func apply(enemy: Enemy) -> void:
	if enemy == null:
		return

	enemy.apply_tutorial_profile()

	var stats := enemy.get_node_or_null("Stats") as CharacterStats
	if stats:
		stats.max_hp = TUTORIAL_CONFIG.hp
		stats.current_hp = TUTORIAL_CONFIG.hp
		stats.strength = 0
		stats.magic = 0
		stats.dexterity = 0
		stats.strength_mod = 0
		stats.magic_mod = 0
		stats.dexterity_mod = 0
		stats.hp_changed.emit(stats.current_hp, stats.max_hp)
		stats.stats_changed.emit()

	var combat_component := enemy.get_combat_component()
	if combat_component:
		# Training dummy behavior: always harmless while staying in the same combat system.
		combat_component.base_damage = TUTORIAL_CONFIG.base_damage
		combat_component.forced_miss_chance = TUTORIAL_CONFIG.forced_miss_chance

	if enemy.has_method("set_visual_tint"):
		enemy.set_visual_tint(TUTORIAL_CONFIG.base_tint, TUTORIAL_CONFIG.target_tint)
