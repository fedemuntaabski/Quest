extends RefCounted
class_name EnemyProfileApplier

const STANDARD_ENEMY_HP := 10
const STANDARD_ENEMY_STRENGTH := 1
const STANDARD_ENEMY_MAGIC := 0
const STANDARD_ENEMY_DEX := 0
const STANDARD_ENEMY_BASE_DAMAGE := 1
@export_range(0.0, 1.0, 0.01) var forced_miss_chance: float = 0.0

static func apply_standard_profile(stats: CharacterStats) -> void:
	if stats == null:
		return
	stats.max_hp = STANDARD_ENEMY_HP
	stats.current_hp = STANDARD_ENEMY_HP
	stats.strength = STANDARD_ENEMY_STRENGTH
	stats.magic = STANDARD_ENEMY_MAGIC
	stats.dexterity = STANDARD_ENEMY_DEX
	stats.strength_mod = 0
	stats.magic_mod = 0
	stats.dexterity_mod = 0
	stats.hp_changed.emit(stats.current_hp, stats.max_hp)
	stats.stats_changed.emit()

static func apply_standard_combat_profile(combat_component: CombatComponent) -> void:
	if combat_component == null:
		return
	combat_component.base_damage = STANDARD_ENEMY_BASE_DAMAGE
	combat_component.attack_range = 1
	


static func apply_combat_from_data(combat_component: CombatComponent, data: EnemyData) -> void:
	if combat_component == null or data == null:
		return
	combat_component.base_damage = data.base_damage
	combat_component.attack_range = max(1, data.attack_range)
	combat_component.forced_miss_chance = clampf(data.forced_miss_chance, 0.0, 1.0)



# 🌟 CORREGIDO: Ahora acepta AnimatedSprite2D como tercer argumento
static func apply_enemy_data(
	data: EnemyData,
	stats: CharacterStats,
	sprite: AnimatedSprite2D,
	health_bar: ProgressBar,
	combat_component: CombatComponent,
	set_visual_tint: Callable,
	apply_tutorial_profile: Callable
) -> Dictionary:
	if data == null:
		return {}

	if stats:
		stats.character_name = data.enemy_name
		stats.max_hp = max(1, data.max_hp)
		stats.current_hp = stats.max_hp
		stats.strength = data.strength
		stats.magic = data.magic
		stats.dexterity = data.dexterity
		stats.strength_mod = 0
		stats.magic_mod = 0
		stats.dexterity_mod = 0
		stats.hp_changed.emit(stats.current_hp, stats.max_hp)
		stats.stats_changed.emit()

	var next_step_time = max(0.01, data.move_step_time)
	var next_movement_points = max(1, data.movement)

	# 🌟 MODIFICADO: Se comenta esta línea porque la textura ahora la maneja el SpriteFrames de las animaciones
	# if sprite and data.sprite_texture:
	# 	sprite.texture = data.sprite_texture

	if set_visual_tint.is_valid():
		set_visual_tint.call(data.base_tint, data.target_tint)

	if health_bar:
		health_bar.max_value = stats.max_hp if stats else data.max_hp
		health_bar.value = stats.current_hp if stats else data.max_hp

	if data.enemy_id == "tutorial" or data.tags.has("tutorial"):
		if apply_tutorial_profile.is_valid():
			apply_tutorial_profile.call()

	if combat_component:
		apply_combat_from_data(combat_component, data)

	return {
		"step_time": next_step_time,
		"movement_points": next_movement_points,
	}
