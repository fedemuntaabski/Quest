extends Node
class_name HeroAbilities

## HeroAbilities: runtime of one hero's passive + active (AbilityData). Child of
## Player. Passives are read where they act: incoming_damage() (Player._on_hurt)
## and FloorManager.on_room_discovered (passive_discovery_bonus). The active
## fires on the `hero_ability` action (Q) for every selected hero, then waits
## `cooldown` seconds. Cooldowns and buff timers run on game time, so the
## tactical pause (time_scale 0) freezes them.

signal ability_used(hero_id: String, ability: AbilityData)
signal cooldown_changed(left: float, total: float)

const MAX_REDUCTION := 0.9

var hero: Player
var passive: AbilityData
var active: AbilityData
var ability_name: String = ""
var cooldown_left: float = 0.0


func setup(p_hero: Player, data: CharacterData) -> void:
	hero = p_hero
	passive = data.passive
	var player_stats := ManagerLocator.get_player_stats()
	if player_stats:
		player_stats.run_upgrades_changed.connect(_on_upgrade)
		player_stats.perk_chosen.connect(_on_perk_chosen)
	active = data.active
	ability_name = data.active_ability_name


func _process(delta: float) -> void:
	if cooldown_left <= 0.0:
		return
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	cooldown_changed.emit(cooldown_left, active_cooldown())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("hero_ability") and not event.is_echo() and _input_allowed():
		try_activate()


func _input_allowed() -> bool:
	var selection := ManagerLocator.get_selection_manager()
	var state := ManagerLocator.get_game_state_manager()
	return Engine.time_scale > 0.0 and (state == null or state.is_active()) \
		and selection != null and selection.is_selected(hero.stats.hero_id)


# ---------------- numbers (AbilityData + class perks) ----------------

## Sum of this hero's chosen perks for `key` (HeroPerk.MOD_KEYS).
func perk_mod(key: String) -> float:
	var player_stats := ManagerLocator.get_player_stats()
	return player_stats.perk_mod(hero.stats.hero_id, key) if player_stats else 0.0


func active_cooldown() -> float:
	return maxf(active.cooldown + perk_mod("active_cooldown"), 1.0) if active else 0.0


func active_value() -> float:
	return (active.value + perk_mod("active_value")) if active else 0.0


func active_duration() -> float:
	return (active.duration + perk_mod("active_duration")) if active else 0.0


func passive_value() -> float:
	return (passive.value + perk_mod("passive_value")) if passive else 0.0


func passive_radius() -> float:
	return (passive.radius + perk_mod("passive_radius")) if passive else 0.0


# ---------------- passives ----------------

## Fraction of incoming damage ignored by this hero's passive right now.
func passive_reduction() -> float:
	if passive == null:
		return 0.0
	match passive.effect:
		AbilityData.Effect.DAMAGE_REDUCTION_PCT:
			return passive_value()
		AbilityData.Effect.NEXO_PROXIMITY_REDUCTION:
			var nexo := ManagerLocator.get_nexo()
			var radius := passive_radius()
			if nexo == null or radius <= 0.0:
				return 0.0
			return passive_value() * clampf(1.0 - hero.global_position.distance_to(nexo.get_target_position()) / radius, 0.0, 1.0)
	return 0.0


## Damage after the passive and any TEAM_SHIELD (never below 1).
func incoming_damage(amount: int) -> int:
	var keep := (1.0 - minf(passive_reduction(), MAX_REDUCTION)) * hero.stats.damage_taken_mult
	return maxi(1, roundi(amount * keep))


## Resource gained when a room is discovered: {"science": n, "dust": n}.
func passive_discovery_bonus() -> Dictionary:
	if passive == null:
		return {}
	match passive.effect:
		AbilityData.Effect.SCIENCE_ON_DISCOVERY:
			return {"science": roundi(passive_value())}
		AbilityData.Effect.DUST_ON_DISCOVERY:
			return {"dust": roundi(passive_value())}
	return {}


# ---------------- active ----------------

func is_ready() -> bool:
	return active != null and cooldown_left <= 0.0 and hero.stats.is_alive()


## Fires the active if it is off cooldown. Returns whether it fired.
func try_activate() -> bool:
	if active == null or not hero.stats.is_alive():
		return false
	if cooldown_left > 0.0:
		_say("%s (%d s)" % [ability_name, ceili(cooldown_left)], QuestPalette.PARCHMENT)
		return false
	match active.effect:
		AbilityData.Effect.TEAM_ATTACK_BUFF:
			for ally in _allies_in_room():
				_buff(ally.stats, "attack_buff", func() -> void: ally.stats.set_attack_mult(1.0 + active_value()), func() -> void: ally.stats.set_attack_mult(1.0))
		AbilityData.Effect.TEAM_SHIELD:
			for ally in ManagerLocator.get_heroes():
				if ally.stats.is_alive():
					_buff(ally.stats, "shield", func() -> void: ally.stats.damage_taken_mult = 1.0 - active_value(), func() -> void: ally.stats.damage_taken_mult = 1.0)
		AbilityData.Effect.MODULE_OVERCHARGE:
			_overcharge_room()
		AbilityData.Effect.BURST_STRIKE:
			_burst_strike()
		_:
			return false
	cooldown_left = active_cooldown()
	cooldown_changed.emit(cooldown_left, active_cooldown())
	_say(ability_name, hero.vfx_color())
	_play_cast_vfx()
	ability_used.emit(hero.stats.hero_id, active)
	QuestLogger.info(QuestLogger.Category.COMBAT, "%s used '%s'." % [hero.stats.hero_id, active.id])
	return true


func _play_cast_vfx() -> void:
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx == null or active.vfx == &"":
		return
	var targets: Array[Player] = []
	match active.effect:
		AbilityData.Effect.TEAM_ATTACK_BUFF:
			targets = _allies_in_room()
		AbilityData.Effect.TEAM_SHIELD:
			for ally in ManagerLocator.get_heroes():
				if ally.stats.is_alive():
					targets.append(ally)
		_:
			targets = [hero]
	for target in targets:
		vfx.play(active.vfx, target.global_position, hero.vfx_color())
	if active.effect == AbilityData.Effect.BURST_STRIKE:
		vfx.shake()


## Level-up aura on the hero that just bought a level.
func _on_upgrade(stat_key: String, _level: int, hero_id: String) -> void:
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx and stat_key == "level" and hero_id == hero.stats.hero_id:
		vfx.play(&"level_up", hero.global_position, hero.vfx_color())


## Class perk picked: same aura as a level-up; a running cooldown is capped to the new total.
func _on_perk_chosen(hero_id: String, _perk_id: StringName) -> void:
	if hero_id != hero.stats.hero_id:
		return
	_on_upgrade("level", 0, hero_id)
	if active:
		cooldown_left = minf(cooldown_left, active_cooldown())


func _allies_in_room() -> Array[Player]:
	var allies: Array[Player] = []
	for ally in ManagerLocator.get_heroes():
		if ally.stats.is_alive() and ally.current_zone_id == hero.current_zone_id:
			allies.append(ally)
	return allies


## Applies a timed effect on `target`; a newer cast of the same `key` supersedes
## the revert of an older one.
func _buff(target: Object, key: String, apply: Callable, revert: Callable) -> void:
	apply.call()
	var token := Time.get_ticks_usec()
	target.set_meta(key, token)
	await get_tree().create_timer(active_duration()).timeout
	if is_instance_valid(target) and target.get_meta(key, 0) == token:
		revert.call()


func _overcharge_room() -> void:
	var room_manager := ManagerLocator.get_room_manager()
	var resources := ManagerLocator.get_resource_manager()
	if room_manager == null:
		return
	for module in room_manager.get_modules_in_group(room_manager.get_group_id(hero.current_zone_id)):
		if module is TurretModule:
			_buff(module, "overcharge", func() -> void: module.damage_mult = 1.0 + active_value(), func() -> void: module.damage_mult = 1.0)
		elif module is GeneratorModule and resources:
			resources.add_resource(module.resource_type, module.yield_amount)


func _burst_strike() -> void:
	var damage := roundi(hero.stats.effective_attack_damage() * active_value())
	for area in hero.hitbox.get_overlapping_areas():
		var hurtbox := area as HurtboxComponent
		if hurtbox == null:
			continue
		hurtbox.receive_hit(damage)
		hero.hitbox.hit_landed.emit(hurtbox, damage)


func _say(text: String, color: Color) -> void:
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	if text_mgr:
		text_mgr.spawn_text(hero.global_position + Vector2(0.0, -48.0), text, color)
