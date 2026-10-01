extends SceneTree

## VfxManager (session balance-4): every configured effect has its scene and sheet,
## square 1-2 art-px particles with Nearest, pooling reuses nodes, the simultaneous
## cap holds, and the screen shake only fires on strong hits and obeys the setting.
##   godot --headless --path . --script res://tests/test_vfx.gd

const EFFECT_SCENES: Array[String] = ["slash_arc", "projectile_trail", "impact_sparks", "heal_glow", "buff_aura", "death_dust", "damage_flash"]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var vfx := VfxManager.new()
	root.add_child(vfx)
	await process_frame
	_check_config(vfx)
	await _check_pool(vfx)
	_check_cap(vfx)
	_check_shake(vfx)
	await _check_ability_ids(vfx)
	vfx.free()  # the hooks below create their own (default-config) manager lazily
	await _check_hooks()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_vfx: %s (%d checks, %d failures)" % ["OK" if failures.is_empty() else "FAILED", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func _check_config(vfx: VfxManager) -> void:
	var used: Array[String] = []
	for id in vfx.config.effects:
		var def: Dictionary = vfx.config.effects[id]
		var scene_name := String(def["scene"])
		_expect(EFFECT_SCENES.has(scene_name), "%s: unknown scene '%s'" % [id, scene_name])
		used.append(scene_name)
		var sheet := String(def.get("sheet", ""))
		if sheet != "":
			_expect(VfxEffect.frames_for(sheet) != null, "%s: sheet '%s' missing from index.json or not imported" % [id, sheet])
	for scene_name in EFFECT_SCENES:
		_expect(used.has(scene_name), "scene %s is not used by any effect" % scene_name)
		var effect := (load(VfxManager.SCENE_PATH % scene_name) as PackedScene).instantiate() as VfxEffect
		_expect(effect != null, "%s does not load as a VfxEffect" % scene_name)
		if effect == null:
			continue
		_expect(effect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s: root filter must be Nearest" % scene_name)
		var particles := effect.get_node_or_null("Particles") as CPUParticles2D
		if particles:
			_expect(particles.scale_amount_min >= ArtConfig.ART_SCALE and particles.scale_amount_max <= 2.0 * ArtConfig.ART_SCALE, "%s: particles must be 1-2 art px squares" % scene_name)
			_expect(particles.texture == null and particles.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s: particles must be plain Nearest squares" % scene_name)
		effect.free()


func _check_pool(vfx: VfxManager) -> void:
	var effect := vfx.play(&"hit_sparks", Vector2(10, 10), Color.RED)
	_expect(effect != null and vfx.get_active_count() == 1 and effect.visible, "play did not start an effect")
	await create_timer(0.6).timeout
	_expect(vfx.get_active_count() == 0 and not effect.visible, "effect did not return to the pool")
	var again := vfx.play(&"hit_sparks", Vector2.ZERO, Color.BLUE)
	_expect(again == effect and vfx.get_child_count() == 1, "pool did not reuse the node (children: %d)" % vfx.get_child_count())
	await create_timer(0.6).timeout
	_expect(vfx.play(&"no_such_effect", Vector2.ZERO) == null, "unknown effect id must be ignored")


func _check_cap(vfx: VfxManager) -> void:
	vfx.config = vfx.config.duplicate()
	vfx.config.max_active = 3
	var played := 0
	for i in 10:
		if vfx.play(&"damage_flash", Vector2(i, 0), Color.RED) != null:
			played += 1
	_expect(played == 3 and vfx.get_active_count() == 3, "cap: %d effects played (want 3)" % played)


func _check_shake(vfx: VfxManager) -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var camera := GameCamera.new()
	holder.add_child(camera)
	camera.make_current()
	var settings := ManagerLocator.get_settings_manager()
	var saved: float = settings.screen_shake_intensity
	settings.screen_shake_intensity = 1.0
	var min_damage := vfx.config.shake_min_damage
	vfx.shake_if_strong(min_damage - 1, 1)
	_expect(camera._shake_left <= 0.0, "a weak hit (%d dmg) must not shake" % (min_damage - 1))
	vfx.shake_if_strong(min_damage, int(min_damage / vfx.config.shake_threshold_pct) + 10)
	_expect(camera._shake_left <= 0.0, "a hit under the HP threshold must not shake")
	vfx.shake_if_strong(min_damage, min_damage)
	_expect(camera._shake_left > 0.0 and camera._shake_strength <= vfx.config.shake_strength, "a strong hit must shake, lightly")
	camera._shake_left = 0.0
	camera._shake_strength = 0.0
	settings.screen_shake_intensity = 0.0
	vfx.shake_if_strong(min_damage, min_damage)
	_expect(camera._shake_strength == 0.0, "shake must be off when the setting is 0")
	settings.screen_shake_intensity = saved
	holder.free()


## Every ability references an effect that exists.
func _check_ability_ids(vfx: VfxManager) -> void:
	for id in BalanceSim.HERO_IDS:
		var active := BalanceSim.hero_data(id).active
		_expect(active.vfx != &"" and not vfx.config.get_effect(active.vfx).is_empty(), "%s: active vfx '%s' not configured" % [id, active.vfx])


func _active_scenes(vfx: VfxManager) -> Array[String]:
	var names: Array[String] = []
	for effect: VfxEffect in vfx.get_children():
		if effect.visible:
			names.append(effect.scene_name)
	return names


## Live Main2d: combat events spawn effects, effects never change the combat result, the cap holds.
func _check_hooks() -> void:
	var main2d := (load("res://scenes/Main2d.tscn") as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	var vfx := ManagerLocator.get_vfx_manager()
	vfx.clear()
	var hero: Player = main2d.heroes[0]
	var start_id: String = main2d.room_manager.get_start_zone_id()
	var enemy := main2d.enemy_manager._spawn_enemy(start_id, hero.global_position) as Enemy

	hero.hitbox.hit_landed.emit(enemy.hurtbox, 3)
	_expect(_active_scenes(vfx).has("slash_arc") and _active_scenes(vfx).has("impact_sparks"), "hero hit: no slash/sparks (%s)" % [_active_scenes(vfx)])
	var hp := hero.stats.current_hp
	hero.stats.take_damage(2)
	_expect(hero.stats.current_hp == hp - 2 and _active_scenes(vfx).has("damage_flash"), "hero hurt: wrong HP or no flash")
	enemy.take_damage(9999)
	_expect(not enemy.is_alive() and _active_scenes(vfx).has("death_dust"), "enemy death: no dust")
	hero.stats.heal(2)
	_expect(hero.stats.current_hp == hp, "heal altered by effects")

	for i in 200:
		hero.hitbox.hit_landed.emit(hero.hurtbox, 3)
	_expect(vfx.get_active_count() <= vfx.config.max_active, "cap exceeded: %d" % vfx.get_active_count())
	main2d.queue_free()
	await process_frame
	await process_frame
	_expect(vfx.get_active_count() == 0, "effects left after the floor was freed")
