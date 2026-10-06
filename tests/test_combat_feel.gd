extends SceneTree

## heroes-9 combat feel: heroes hit only the nearest enemy in range
## (HitboxComponent.single_target), the Mage's hit travels as a Projectile and
## lands on arrival, enemies show an HP bar only once damaged, and a hit pushes
## the sprite back (visual only) and returns.
##   godot --headless --path . --script res://tests/test_combat_feel.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const ENEMY_PATH := "res://scenes/entities/Enemy.tscn"

var failures: Array[String] = []


func _initialize() -> void:
	await _check_single_target()
	await _check_projectile()

	var session := root.get_node("GameSession")
	session.clear()
	session.set_selection(["mage", "rogue"] as Array[String])
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	var mage: Player = main2d.heroes[0]
	var rogue: Player = main2d.heroes[1]
	_expect(mage.is_ranged() and mage.hitbox.deliver.is_valid() and mage.hitbox.single_target, "mage: ranged, single target")
	_expect(not rogue.is_ranged() and not rogue.hitbox.deliver.is_valid() and rogue.hitbox.single_target, "rogue: melee, single target")
	_expect(rogue.move_speed_mult() > 1.0 and mage.move_speed_mult() == 1.0, "rogue moves faster")
	await _check_enemy_feedback(main2d)
	main2d.queue_free()
	await process_frame
	session.clear()

	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_combat_feel: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _hurtbox(at: Vector2) -> HurtboxComponent:
	var hurtbox := HurtboxComponent.new()
	hurtbox.collision_layer = 8
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	hurtbox.add_child(shape)
	root.add_child(hurtbox)
	hurtbox.global_position = at
	return hurtbox


func _hitbox(at: Vector2, single: bool) -> HitboxComponent:
	var hitbox := HitboxComponent.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 8
	hitbox.single_target = single
	hitbox.show_damage_numbers = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 200.0
	shape.shape = circle
	hitbox.add_child(shape)
	root.add_child(hitbox)
	hitbox.global_position = at
	return hitbox


func _check_single_target() -> void:
	var near := _hurtbox(Vector2(1000, 1050))
	var far := _hurtbox(Vector2(1000, 1150))
	var hits := {"near": 0, "far": 0}
	near.hurt.connect(func(_a: int) -> void: hits["near"] += 1)
	far.hurt.connect(func(_a: int) -> void: hits["far"] += 1)
	var single := _hitbox(Vector2(1000, 1000), true)
	var aoe := _hitbox(Vector2(1000, 1000), false)
	await physics_frame
	await physics_frame
	await physics_frame
	_expect(single.pick_targets() == ([near] as Array[HurtboxComponent]), "single target picks the nearest (%d targets)" % single.pick_targets().size())
	_expect(aoe.pick_targets().size() == 2, "contact/AoE hitbox still hits all (%d)" % aoe.pick_targets().size())
	single._on_tick()
	_expect(hits["near"] == 1 and hits["far"] == 0, "one tick = one hit on the nearest: %s" % [hits])
	for node: Node in [near, far, single, aoe]:
		node.queue_free()
	await process_frame


func _check_projectile() -> void:
	var target := _hurtbox(Vector2(3000, 3000))
	var source := _hitbox(Vector2(3000, 3300), true)
	var got := [0]
	var landed := [0]
	target.hurt.connect(func(a: int) -> void: got[0] += a)
	source.hit_landed.connect(func(_t: HurtboxComponent, _a: int) -> void: landed[0] += 1)
	var projectile := Projectile.fire(root, Vector2(3000, 3300), target, source, 7, 900.0, Color.WHITE)
	_expect(got[0] == 0, "no damage until the projectile arrives")
	await process_frame
	_expect(is_instance_valid(projectile) and got[0] == 0, "still flying after one frame")
	var deadline := Time.get_ticks_msec() + 2000
	while is_instance_valid(projectile) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(got[0] == 7 and landed[0] == 1, "projectile lands its damage once (%d, %d)" % [got[0], landed[0]])

	# A target freed mid-flight: the projectile fizzles.
	var gone := _hurtbox(Vector2(3000, 2000))
	var fizzle := Projectile.fire(root, Vector2(3000, 3300), gone, source, 7, 300.0, Color.WHITE)
	gone.queue_free()
	await process_frame
	await process_frame
	_expect(not is_instance_valid(fizzle), "projectile without a target fizzles")
	target.queue_free()
	source.queue_free()
	await process_frame


func _check_enemy_feedback(main2d: Node) -> void:
	var enemy := (load(ENEMY_PATH) as PackedScene).instantiate() as Enemy
	main2d.add_child(enemy)
	var zone: String = main2d.room_manager.get_start_zone_id()
	enemy.setup(main2d.room_manager.get_center(zone) + Vector2(60, 0))
	enemy.configure(Enemy.Variant.SAPPER, zone)
	enemy.ai_timer.stop()
	_expect(not enemy.is_hp_bar_visible(), "no HP bar at full HP")
	var rest := enemy.visual.position
	enemy.take_damage(1)
	_expect(enemy.is_hp_bar_visible(), "HP bar once damaged (%d/%d)" % [enemy.current_hp, enemy.max_hp])
	_expect(enemy.visual.is_knocked_back(), "hit pushes the enemy sprite back")
	for i in 30:
		await process_frame
	_expect(enemy.visual.position.is_equal_approx(rest) and not enemy.visual.is_knocked_back(), "sprite returns to its place")
	enemy.queue_free()
