extends SceneTree

## Headless self-check for the sprite integration (assets-3): hero SpriteFrames,
## per-floor enemy pools (data + variety), Enemy/Player visuals + collision fit
## with combat numbers untouched, CharacterVisual states (run/flip/hit/procedural
## idle), pickups, HUD portrait. Run:
##   godot --headless --path . --script res://tests/test_sprites.gd

var failures: Array[String] = []


func _initialize() -> void:
	var config := load("res://resources/floors/default_floor_config.tres") as FloorConfig
	_check_heroes()
	_check_pools(config)
	await _check_enemy(config)
	await _check_player()
	await _check_visual_states()
	await _check_pickups()
	_check_portrait()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_sprites: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _check_heroes() -> void:
	for data in CharacterDatabase.get_all():
		var frames := data.sprite_frames
		_expect(frames != null, "%s: no sprite_frames" % data.character_id)
		if frames == null:
			continue
		for anim in ["idle", "run", "hit"]:
			_expect(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "%s: missing '%s' frames" % [data.character_id, anim])
		_expect(frames.get_frame_count("idle") == 4 and frames.get_frame_count("run") == 4, "%s: idle/run should have 4 frames" % data.character_id)
		_expect(frames.get_frame_texture("idle", 0).get_size() == Vector2(16, 28), "%s: idle frame is not 16x28" % data.character_id)


func _check_pools(config: FloorConfig) -> void:
	var seen_floor_one: Dictionary = {}
	var previous: Array[String] = []
	var last: Array[String] = []
	for floor_index in range(1, config.max_floors + 1):
		var pool := config.enemy_pool(floor_index)
		_expect(pool != null and not pool.types.is_empty(), "floor %d: empty enemy pool" % floor_index)
		if pool == null:
			continue
		_expect(pool.weights.size() == pool.types.size(), "floor %d: weights/types size mismatch" % floor_index)
		var total := 0.0
		var ids: Array[String] = []
		for i in pool.types.size():
			var type := pool.types[i]
			total += pool.weight_of(i)
			ids.append(type.id)
			_expect(type.sprite_frames != null and type.sprite_frames.has_animation("idle"), "%s: no idle animation" % type.id)
			_expect(type.behavior >= 0 and type.behavior <= 2, "%s: bad behavior %d" % [type.id, type.behavior])
			_expect(type.hp_mult > 0.0 and type.damage_mult > 0.0 and type.speed_mult > 0.0, "%s: non-positive multiplier" % type.id)
			if floor_index == 1:
				seen_floor_one[type.id] = true
		_expect(total > 0.0, "floor %d: pool weights sum to 0" % floor_index)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 20:
			_expect(pool.types.has(pool.roll(rng)), "floor %d: roll returned a type outside the pool" % floor_index)
		_expect(ids != previous, "floor %d: pool identical to floor %d" % [floor_index, floor_index - 1])
		previous = ids
		last = ids
	var new_in_last := 0
	for id in last:
		new_in_last += int(not seen_floor_one.has(id))
	_expect(new_in_last >= 3, "last floor should introduce new enemies (got %d)" % new_in_last)
	_expect(config.enemy_pool(config.max_floors + 3) == config.enemy_pool(config.max_floors), "floors past the last pool should reuse it")
	var has_static := false
	for pool in config.enemy_pools:
		for type in pool.types:
			has_static = has_static or not type.sprite_frames.has_animation("run")
	_expect(has_static, "no Tiny Creatures (static) type in any pool")


func _check_enemy(config: FloorConfig) -> void:
	var small := load("res://resources/enemies/goblin.tres") as EnemyType
	var big := load("res://resources/enemies/big_demon.tres") as EnemyType
	var scene := load("res://scenes/entities/Enemy.tscn") as PackedScene
	var radii: Array[float] = []
	for type in [small, big]:
		var enemy := scene.instantiate() as Enemy
		root.add_child(enemy)
		await process_frame
		enemy.configure(Enemy.Variant.SWARM, "z", 2.0, 3.0, type)
		var cfg: Dictionary = Enemy.VARIANT_CONFIG[type.behavior]
		_expect(enemy.variant == type.behavior, "%s: behavior not applied" % type.id)
		_expect(enemy.max_hp == maxi(1, roundi(int(cfg["hp"]) * 2.0 * type.hp_mult)), "%s: hp %d not from variant x floor x type" % [type.id, enemy.max_hp])
		_expect(enemy.hitbox.damage == maxi(1, roundi(int(cfg["contact_damage"]) * 3.0 * type.damage_mult)), "%s: contact damage changed" % type.id)
		_expect(is_equal_approx(enemy.hitbox.hit_interval, Enemy.CONTACT_HIT_INTERVAL), "%s: hit interval changed" % type.id)
		var expected := maxf(enemy.visual.body_size().x, enemy.visual.body_size().y) * CharacterVisual.BODY_RADIUS_FACTOR
		var hurt_shape := enemy.hurtbox.get_node("CollisionShape2D") as CollisionShape2D
		_expect(is_equal_approx((hurt_shape.shape as CircleShape2D).radius, expected), "%s: hurtbox radius not fitted" % type.id)
		_expect(is_equal_approx(((enemy.hitbox.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius, expected + Enemy.CONTACT_REACH), "%s: contact hitbox not fitted" % type.id)
		_expect(enemy.visual.sprite_frames == type.sprite_frames and enemy.visual.visible, "%s: visual not applied" % type.id)
		_expect(enemy.visual.scale == Vector2.ONE * ArtConfig.ART_SCALE * type.visual_scale, "%s: sprite not scaled by ART_SCALE" % type.id)
		radii.append(expected)
		enemy.take_damage(1)
		_expect(enemy.visual.flash_amount() > 0.0, "%s: no white flash on damage" % type.id)
		enemy.queue_free()
	_expect(radii[1] > radii[0], "big enemy should have a bigger collision than the small one")


func _check_player() -> void:
	var scene := load("res://scenes/Player.tscn") as PackedScene
	var heroes: Array[Player] = []
	for id in ["warrior", "mage"]:
		var hero := scene.instantiate() as Player
		hero.configure(CharacterDatabase.get_by_id(id))
		root.add_child(hero)
		heroes.append(hero)
	await process_frame
	var a := heroes[0]
	var b := heroes[1]
	_expect(a.animated_sprite.sprite_frames != b.animated_sprite.sprite_frames, "each hero should use its own SpriteFrames")
	var radius := ((a.hurtbox.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
	_expect(is_equal_approx(radius, a.animated_sprite.fit_radius()), "hero hurtbox not fitted to the sprite")
	_expect((a.hurtbox.get_node("CollisionShape2D") as CollisionShape2D).shape != (b.hurtbox.get_node("CollisionShape2D") as CollisionShape2D).shape, "hurtbox shape shared between heroes")
	_expect(is_equal_approx(((a.hitbox.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius, 160.0), "hero attack hitbox radius changed")
	a.stats.take_damage(2)
	_expect(a.animated_sprite.flash_amount() > 0.0, "hero does not flash on damage")
	_expect(b.animated_sprite.flash_amount() == 0.0, "flash leaked to another hero")
	a.stats.heal(2)
	for hero in heroes:
		hero.queue_free()


func _check_visual_states() -> void:
	var frames := CharacterDatabase.get_by_id("warrior").sprite_frames
	var visual := CharacterVisual.new()
	root.add_child(visual)
	visual.setup(frames)
	await process_frame
	_expect(visual.state == CharacterVisual.State.IDLE and visual.animation == &"idle", "should start idle")
	for i in 3:
		visual.global_position += Vector2(-6, 0)
		await process_frame
	_expect(visual.state == CharacterVisual.State.RUN and visual.animation == &"run", "moving should play run")
	_expect(visual.flip_h, "moving left should flip")
	visual.global_position += Vector2(6, 0)
	await process_frame
	_expect(not visual.flip_h, "moving right should unflip")
	await create_timer(0.4).timeout
	_expect(visual.state == CharacterVisual.State.IDLE, "should return to idle when still")
	visual.global_position += Vector2(300, 0)
	await process_frame
	_expect(visual.state == CharacterVisual.State.IDLE, "a teleport must not count as running")
	visual.play_hit()
	_expect(visual.flash_amount() == 1.0 and visual.animation == &"hit", "hit should flash and play the hit animation")
	await create_timer(0.4).timeout
	_expect(visual.flash_amount() < 0.05 and visual.animation == &"idle", "hit should fade back to idle")
	visual.queue_free()

	var tc := CharacterVisual.new()
	root.add_child(tc)
	tc.setup((load("res://resources/enemies/tc_wolf.tres") as EnemyType).sprite_frames)
	await process_frame
	var y0 := tc.offset.y
	await create_timer(0.25).timeout
	_expect(not tc.sprite_frames.has_animation("run"), "Tiny Creatures should be single static sprites")
	_expect(not is_equal_approx(tc.offset.y, y0), "static sprite should bounce procedurally")
	tc.queue_free()


func _check_pickups() -> void:
	var scene := load("res://scenes/world/Pickup.tscn") as PackedScene
	for kind in Pickup.Kind.values():
		var pickup := scene.instantiate() as Pickup
		pickup.kind = kind
		root.add_child(pickup)
		await process_frame
		var y0 := pickup.sprite.position.y
		_expect(pickup.sprite.texture != null, "pickup %s has no texture" % Pickup.Kind.keys()[kind])
		await create_timer(0.25).timeout
		_expect(not is_equal_approx(pickup.sprite.position.y, y0), "pickup %s does not float" % Pickup.Kind.keys()[kind])
		pickup.queue_free()
	var nexo := (load("res://scenes/world/Nexo.tscn") as PackedScene).instantiate()
	_expect(nexo.get_node_or_null("Pickup") is Pickup, "Nexo should use the Pickup scene")
	nexo.free()


func _check_portrait() -> void:
	var data := CharacterDatabase.get_by_id("warrior")
	var portrait := HeroPortrait.new()
	portrait.setup(null, data)
	root.add_child(portrait)
	var icon: TextureRect = null
	for node in portrait.find_children("*", "TextureRect", true, false):
		icon = node
		break
	_expect(icon != null, "portrait has no TextureRect icon")
	if icon:
		_expect(icon.texture == data.sprite_frames.get_frame_texture("idle", 0), "portrait should use the idle sprite frame")
		_expect(icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "portrait icon must use Nearest")
	portrait.queue_free()
