extends SceneTree

## personajes-46: two enemies with a role no floor 2-4 enemy had (EnemyType.special):
##  - Calabacero (pumpkin, RANGED): shoots a Projectile at a hero within shot_range, from afar;
##  - Curandero del Pantano (swampy, HEALER): heals the wounded enemies around it.
## Each one exists, has its special role, a TargetProfile, bestiary text, art, and is in the
## floor 2, 3 and 4 pools; then each role is checked on a live Main2d.
##   godot --headless --path . --script res://tests/test_enemigos_nuevos.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const GOBLIN_PATH := "res://resources/enemies/goblin.tres"
## id -> EnemyType.special (1 RANGED, 2 HEALER).
const NEW := {"pumpkin": 1, "swampy": 2}
const FAR := Vector2(9000, 9000)

var failures: Array[String] = []


func _initialize() -> void:
	var types := {}
	for id: String in NEW:
		var path := "res://resources/enemies/%s.tres" % id
		_expect(ResourceLoader.exists(path), "%s: no EnemyType at %s" % [id, path])
		if not ResourceLoader.exists(path):
			continue
		var type := load(path) as EnemyType
		types[id] = type
		_expect(int(type.get("special")) == NEW[id], "%s: special %s, want %d" % [id, type.get("special"), NEW[id]])
		_expect(type.target_profile != null and type.target_profile.id != &"", "%s: no TargetProfile of its own" % id)
		_expect(type.sprite_frames != null and type.sprite_frames.has_animation("idle"), "%s: no idle art" % id)
		_expect(type.display_name != "" and type.description != "" and type.lore != "", "%s: bestiary text missing" % id)
	var config := load("res://resources/floors/default_floor_config.tres") as FloorConfig
	for f in [2, 3, 4]:
		var pool := config.enemy_pool(f)
		var specials := {}
		for type: EnemyType in pool.types:
			specials[int(type.get("special") if type.get("special") != null else 0)] = true
		for id: String in NEW:
			_expect(types.has(id) and pool.types.has(types[id]), "floor %d: %s not in enemy_pool_f%d" % [f, id, f])
		_expect(specials.has(1) and specials.has(2), "floor %d: pool without a ranged and a healer enemy" % f)
	if types.size() == NEW.size():
		await _test_ranged(types["pumpkin"])
		await _test_healer(types["swampy"])
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_enemigos_nuevos: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _boot() -> Node:
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	main2d.standalone_floor = 2
	root.add_child(main2d)
	await process_frame
	main2d.camera.config = main2d.camera.config.duplicate()
	main2d.camera.config.edge_scroll_enabled = false
	return main2d


func _free(main2d: Node) -> void:
	Engine.time_scale = 1.0
	main2d.queue_free()
	await process_frame
	await process_frame


## An Enemy of `type` with its AI timer stopped (it stays where it is put).
func _make_enemy(main2d: Node, type: EnemyType, zone_id: String, pos: Vector2) -> Enemy:
	var enemy := EnemyManager.ENEMY_SCENE.instantiate() as Enemy
	main2d.enemy_manager._enemies_root.add_child(enemy)
	enemy.setup(pos)
	enemy.configure(Enemy.Variant.SWARM, zone_id, 1.0, 1.0, type)
	enemy.ai_timer.stop()
	return enemy


func _wait_game(sec: float) -> void:
	Engine.time_scale = 4.0
	await create_timer(sec).timeout
	Engine.time_scale = 1.0


## The Calabacero hurts a hero out of contact reach and out of the hero's own reach.
func _test_ranged(type: EnemyType) -> void:
	var main2d: Node = await _boot()
	var hero: Player = main2d.heroes[0]
	for other: Player in main2d.heroes.slice(1):
		other.global_position = FAR
	var range_px := float(type.get("shot_range"))
	_expect(range_px > hero.character_data.attack_range + 40.0, "pumpkin: shot_range %.0f does not outrange the %s (%.0f)" % [range_px, hero.stats.hero_id, hero.character_data.attack_range])
	var start := hero.global_position + Vector2(minf(range_px - 20.0, hero.character_data.attack_range + 60.0), 0.0)
	var enemy := _make_enemy(main2d, type, hero.current_zone_id, start)
	var hp := hero.stats.current_hp
	await _wait_game(4.0)
	_expect(hero.stats.current_hp < hp, "pumpkin: a hero %.0f px away took no shot (%d -> %d HP)" % [start.distance_to(hero.global_position), hp, hero.stats.current_hp])
	_expect(is_instance_valid(enemy) and enemy.is_alive(), "pumpkin: died out of the hero's reach")
	await _free(main2d)


## The Curandero heals a wounded Goblin next to it, never above its max HP, and not a far one.
func _test_healer(type: EnemyType) -> void:
	var main2d: Node = await _boot()
	for hero: Player in main2d.heroes:
		hero.global_position = FAR
	var zone_id: String = main2d.heroes[0].current_zone_id
	var center: Vector2 = main2d.room_manager.get_center(zone_id)
	var healer := _make_enemy(main2d, type, zone_id, center)
	var goblin := _make_enemy(main2d, load(GOBLIN_PATH), zone_id, center + Vector2(40, 0))
	var far := _make_enemy(main2d, load(GOBLIN_PATH), zone_id, center + Vector2(float(type.get("heal_radius")) + 200.0, 0))
	goblin.max_hp = 40
	goblin.current_hp = 10
	far.max_hp = 40
	far.current_hp = 10
	await _wait_game(float(type.get("heal_interval")) * 2.5)
	_expect(goblin.current_hp > 10, "swampy: the Goblin next to it was not healed (%d HP)" % goblin.current_hp)
	_expect(goblin.current_hp <= goblin.max_hp, "swampy: healed above max HP")
	_expect(far.current_hp == 10, "swampy: healed a Goblin out of heal_radius (%d HP)" % far.current_hp)
	_expect(healer.is_alive(), "swampy: died")
	await _free(main2d)
