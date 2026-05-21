extends RefCounted
class_name EnemyDataSelector

static func select_enemy_data(room_id: int, final_room_id: int, enemy_data_pool: Array[EnemyData], default_enemy_data: EnemyData) -> EnemyData:
	if room_id == 0:
		var tutorial := find_enemy_data_by_id(enemy_data_pool, "tutorial")
		if tutorial:
			return tutorial

	if room_id == final_room_id:
		var boss_candidates: Array[EnemyData] = []
		for data in enemy_data_pool:
			if data and data.is_boss:
				boss_candidates.append(data)
		if not boss_candidates.is_empty():
			return boss_candidates[randi() % boss_candidates.size()]

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
		return candidates[randi() % candidates.size()]

	if default_enemy_data:
		return default_enemy_data

	return find_enemy_data_by_id(enemy_data_pool, "goblin")

static func find_enemy_data_by_id(enemy_data_pool: Array[EnemyData], enemy_id: String) -> EnemyData:
	for data in enemy_data_pool:
		if data and data.enemy_id == enemy_id:
			return data
	return null
