class_name BossBrain
extends Node

## BossBrain (progresion-10): the simple pattern of a boss Enemy (EnemyType.is_boss),
## added by Enemy.configure. Game time (frozen in the tactical pause, doubled at 2x).
##  - Embestida: every charge_cooldown, if a living hero is within charge_range, the
##    boss turns red for TELEGRAPH_SEC and dashes to where the hero WAS; every hero
##    within charge_radius of that point takes charge_damage (x the floor multiplier).
##  - Phase 2 (boss_phases 2, HP <= boss_phase2_pct): flash + "¡Fase 2!", charges
##    PHASE2_CHARGE_MULT faster and summons summon_count summon_type every summon_cooldown.

signal phase_changed(phase: int)
signal charged(target_point: Vector2, heroes_hit: int)

const TELEGRAPH_SEC := 0.55
const DASH_SEC := 0.22
const PHASE2_CHARGE_MULT := 0.7
const TELEGRAPH_COLOR := Color(1.0, 0.35, 0.3)

var enemy: Enemy
var phase: int = 1
var _charge_clock: float = 0.0
var _summon_clock: float = 0.0


func setup(p_enemy: Enemy) -> void:
	enemy = p_enemy


func _process(delta: float) -> void:
	if enemy == null or not enemy.is_alive():
		return
	_check_phase()
	var type := enemy.type
	_charge_clock += delta
	if not enemy.charging and _charge_clock >= type.charge_cooldown * (PHASE2_CHARGE_MULT if phase >= 2 else 1.0):
		_charge_clock = 0.0
		try_charge()
	if phase >= 2 and type.summon_type and type.summon_count > 0:
		_summon_clock += delta
		if _summon_clock >= type.summon_cooldown:
			_summon_clock = 0.0
			summon()


func _check_phase() -> void:
	if phase >= 2 or enemy.type.boss_phases < 2 or enemy.current_hp > enemy.max_hp * enemy.type.boss_phase2_pct:
		return
	phase = 2
	enemy.visual.play_hit()
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	if text_mgr:
		text_mgr.spawn_text(enemy.global_position + Vector2(0, -80), "¡Fase 2!", QuestPalette.BLOOD_LIGHT, true, 1.6)
	phase_changed.emit(phase)
	summon()


## Nearest living hero within charge_range, or null.
func charge_target() -> Player:
	var best: Player = null
	var best_d := enemy.type.charge_range
	for hero in ManagerLocator.get_heroes():
		if not hero.stats.is_alive():
			continue
		var d := enemy.global_position.distance_to(hero.global_position)
		if d <= best_d:
			best_d = d
			best = hero
	return best


## Telegraph + dash. False when nobody is in range or the boss is walking a path.
func try_charge() -> bool:
	var hero := charge_target()
	if hero == null or enemy.is_moving():
		return false
	var point := hero.global_position
	var zone_id := hero.current_zone_id
	enemy.charging = true
	var base_modulate := enemy.visual.modulate
	var tween := enemy.create_tween()
	tween.tween_property(enemy.visual, "modulate", TELEGRAPH_COLOR, TELEGRAPH_SEC)
	tween.tween_property(enemy, "global_position", point, DASH_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_land_charge.bind(point, zone_id, base_modulate))
	return true


func _land_charge(point: Vector2, zone_id: String, base_modulate: Color) -> void:
	enemy.charging = false
	enemy.visual.modulate = base_modulate
	if not enemy.is_alive():
		return
	enemy.current_zone_id = zone_id
	var damage := maxi(1, roundi(enemy.type.charge_damage * enemy.dmg_multiplier))
	var hit := 0
	for hero in ManagerLocator.get_heroes():
		if hero.stats.is_alive() and hero.global_position.distance_to(point) <= enemy.type.charge_radius:
			hero.stats.take_damage(damage)
			hit += 1
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx:
		vfx.play(&"death_dust", point, vfx.config.enemy_hit_color)
	charged.emit(point, hit)


func summon() -> int:
	var manager := ManagerLocator.get_enemy_manager()
	if manager == null or enemy.type.summon_type == null:
		return 0
	return manager.spawn_minions(enemy.current_zone_id, enemy.type.summon_type, enemy.type.summon_count)
