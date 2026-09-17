extends RefCounted
class_name EnemyDataSelector

static func select_enemy_data(room_template: String, enemy_data_pool: Array[EnemyData], default_enemy_data: EnemyData, rng: RandomNumberGenerator = null) -> EnemyData:
	if room_template == DungeonGraph.TEMPLATE_TREASURE or room_template == DungeonGraph.TEMPLATE_SHOP:
		return null

	if room_template == "tutorial":
		var tutorial := find_enemy_data_by_id(enemy_data_pool, "tutorial")
		if tutorial:
			return tutorial

	if room_template == "boss":
		var boss_candidates: Array[EnemyData] = []
		for data in enemy_data_pool:
			if data and data.is_boss:
				boss_candidates.append(data)
		if not boss_candidates.is_empty():
			return boss_candidates[rng.randi_range(0, boss_candidates.size() - 1) if rng else randi() % boss_candidates.size()]

	var candidates: Array[EnemyData] = []
	for data in enemy_data_pool:
		if data == null:
			continue
		if data.is_boss:
			continue
		if data.enemy_id == "tutorial":
			continue
		candidates.append(data)

	if not candidates.is_empty():
		return candidates[rng.randi_range(0, candidates.size() - 1) if rng else randi() % candidates.size()]

	if default_enemy_data:
		return default_enemy_data

	return find_enemy_data_by_id(enemy_data_pool, "goblin")

static func find_enemy_data_by_id(enemy_data_pool: Array[EnemyData], enemy_id: String) -> EnemyData:
	for data in enemy_data_pool:
		if data and data.enemy_id == enemy_id:
			return data
	return null
