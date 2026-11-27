extends SceneTree

## heroes-47: 8 hunters against 4 heroes in one room spread out. After they close in, no two
## sprites (enemy-enemy or enemy-hero) are closer than MIN_GAP px and every hero has at least one
## enemy after it (TargetSelector spreads hunters; each enemy takes a free place on its hero's ring).
##   godot --headless --path . --script res://tests/test_reparto_sala.gd

const MIN_GAP := 24.0
## Hunter-profile types (HERO_NEAREST), no healer, no boss.
const WAVE := ["skelet", "wogol", "orc_shaman", "tc_eyeball", "skelet", "wogol", "necromancer", "skelet"]

var failures: Array[String] = []


func _initialize() -> void:
	for layout in [0, 1]:
		await _run(layout)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_reparto_sala: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


## layout 0: wave on a circle around the room; 1: the whole wave from one side.
func _run(layout: int) -> void:
	var session := root.get_node("GameSession")
	session.clear()
	session.set_selection(["cleric", "ranger"] as Array[String])
	root.get_node("PlayerStats").reset_run_upgrades()
	var main2d := (load("res://scenes/Main2d.tscn") as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	main2d.standalone_floor = 1
	root.add_child(main2d)
	await process_frame
	var start: String = main2d.room_manager.get_start_zone_id()
	for id in ["warrior", "mage"]:
		main2d.recruit_hero(id, start)
	main2d.relic.max_hp = 100000
	main2d.relic.current_hp = 100000
	var heroes: Array = main2d.heroes
	for hero: Player in heroes:
		hero.stats.max_hp = 100000
		hero.stats.current_hp = 100000
	var center: Vector2 = main2d.room_manager.get_center(start)
	var enemies: Array[Enemy] = []
	for i in WAVE.size():
		var enemy := EnemyManager.ENEMY_SCENE.instantiate() as Enemy
		main2d.enemy_manager._enemies_root.add_child(enemy)
		var from := Vector2.from_angle(i * TAU / WAVE.size()) * 170.0 if layout == 0 else Vector2(-200.0, -60.0 + i * 16.0)
		enemy.setup(center + from)
		enemy.slot = i
		enemy.configure(Enemy.Variant.SWARM, start, 1000.0, 0.0, load("res://resources/enemies/%s.tres" % WAVE[i]))
		enemies.append(enemy)
	await create_timer(6.0, false).timeout
	var tag := "layout %d" % layout
	var per_hero := {}
	for hero: Player in heroes:
		per_hero[hero.stats.hero_id] = 0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			failures.append("%s: an enemy died" % tag)
			continue
		var target = enemy.selector.current.node if enemy.selector.current else null
		if target is Player:
			per_hero[(target as Player).stats.hero_id] += 1
	for id in per_hero:
		if per_hero[id] < 1:
			failures.append("%s: hero %s has no enemy after it (%s)" % [tag, id, per_hero])
	var points: Array = []
	for hero: Player in heroes:
		points.append(["hero " + hero.stats.hero_id, hero.body_position()])
	for i in enemies.size():
		if is_instance_valid(enemies[i]):
			points.append(["enemy %d" % i, enemies[i].global_position])
	var close := 0
	for a in points.size():
		for b in range(a + 1, points.size()):
			if str(points[a][0]).begins_with("hero") and str(points[b][0]).begins_with("hero"):
				continue
			var d: float = (points[a][1] as Vector2).distance_to(points[b][1])
			if d < MIN_GAP:
				close += 1
				failures.append("%s: %s and %s are %.1f px apart" % [tag, points[a][0], points[b][0], d])
	print("%s: enemies per hero %s, %d pairs closer than %d px" % [tag, per_hero, close, MIN_GAP])
	main2d.queue_free()
	await process_frame
	await process_frame
