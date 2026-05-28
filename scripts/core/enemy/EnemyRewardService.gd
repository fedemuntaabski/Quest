extends RefCounted
class_name EnemyRewardService

static func process_enemy_defeat(manager: EnemyManager, enemy, room_id: int) -> void:
	if manager == null:
		return

	manager.enemy_defeated_global.emit()

	var is_boss := _is_boss_enemy(enemy)

	var reward_gold := manager.COIN_REWARD_PER_ENEMY
	if enemy and enemy.has_method("get_reward_gold"):
		reward_gold = int(enemy.get_reward_gold())

	manager._run_accumulated_gold += max(0, reward_gold)
	print("[EnemyManager] Enemy defeated: +%dg (accumulated total: %dg)" % [reward_gold, manager._run_accumulated_gold])

	if is_boss:
		manager.boss_defeated.emit(enemy)
	else:
		var reward_position: Vector2 = enemy.global_position if enemy and enemy is Node2D else Vector2.ZERO
		manager.enemy_defeated_with_reward.emit(enemy, reward_position)

	if manager.turn_manager:
		manager.turn_manager.unregister_actor(enemy)

	var map_manager := manager.get_parent() as MapManager
	if map_manager and enemy != null:
		map_manager.unregister_actor(enemy)

	manager.enemies.erase(enemy)

	if not manager._room_enemy_counts.has(room_id):
		return

	manager._room_enemy_counts[room_id] -= 1

	if manager._room_enemy_counts[room_id] <= 0:
		manager._room_enemy_counts.erase(room_id)
		manager.room_cleared.emit(room_id)

static func _is_boss_enemy(enemy) -> bool:
	if enemy == null:
		return false
	if enemy is Enemy:
		return (enemy as Enemy).is_boss
	return enemy.get("is_boss") == true

static func grant_and_reset_accumulated_gold(manager: EnemyManager) -> int:
	if manager == null:
		return 0

	if manager._run_accumulated_gold <= 0:
		return 0

	var currency := ManagerLocator.get_currency_manager() as CurrencyManager
	if currency == null:
		push_warning("[EnemyManager] Cannot grant accumulated gold: CurrencyManager not found")
		var temp := manager._run_accumulated_gold
		manager._run_accumulated_gold = 0
		return temp

	var amount := manager._run_accumulated_gold
	currency.add_gold(amount, Vector2.ZERO)
	print("[EnemyManager] Run ended: granted accumulated gold +%dg" % amount)
	manager._run_accumulated_gold = 0
	return amount
