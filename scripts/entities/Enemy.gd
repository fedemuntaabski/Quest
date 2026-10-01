extends CharacterBody2D
class_name Enemy

## Enemy: minimal DotE-style enemy. No real pathfinding — an AiTimer re-
## evaluates a target zone periodically and glides the whole revealed-only
## path there via EnemyMoveAction (same graph RoomManager/PlayerActionController
## already use). Owns a tiny self-contained HP block mirroring
## CharacterStats.take_damage's clamp/signal shape.

enum Variant { SWARM, SAPPER, HUNTER }
enum State { MOVING, ATTACKING }

const VARIANT_CONFIG := {
	Variant.SWARM: {"hp": 6, "speed": 500.0, "ai_interval": 1.2, "contact_damage": 2},
	Variant.SAPPER: {"hp": 10, "speed": 380.0, "damage_per_tick": 3, "ai_interval": 2.0, "contact_damage": 1},
	Variant.HUNTER: {"hp": 8, "speed": 400.0, "ai_interval": 1.2, "contact_damage": 3},
}

const DEFAULT_ATTACK_DAMAGE := 2
## Seconds between contact-damage ticks against the hero (HitboxComponent).
const CONTACT_HIT_INTERVAL := 1.0

## Contact Hitbox reaches this much past the body (px), like the old 14 -> 24.
const CONTACT_REACH := 10.0
## Slot ring (px) around the point an enemy closes in on.
const RING_RADIUS := 14.0
## A raider turns on a hero closer than this (px) or one that hit it in the last REACT_SEC.
const BLOCK_RANGE := 48.0
const RAIDER_TINT := Color(1.0, 0.72, 0.66)
const REACT_SEC := 3.0

signal died(enemy: Enemy)

@onready var visual: CharacterVisual = $Visual
@onready var ai_timer: Timer = $AiTimer
@onready var attack_timer: Timer = $AttackTimer
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var hitbox: HitboxComponent = $Hitbox

@export var attack_speed: float = 1.0
var attack_damage: int = DEFAULT_ATTACK_DAMAGE

var current_state: State = State.MOVING
var target_module: Node2D = null
var variant: Variant
## Art + stat multipliers (null = plain variant, no art). Set by configure().
var type: EnemyType
var role: EnemyType.Role = EnemyType.Role.HUNTER
var aggro_range: float = 320.0
var attack_range: float = 40.0
var nexus_damage: int = 0
var current_zone_id: String = ""
var max_hp: int = 0
var current_hp: int = 0
var _slowed_until_msec: int = 0
var _moving: bool = false
## Zone the current trip was planned for (see goal_changed()).
var _active_goal: String = ""
var _provoked_until_msec: int = 0
var target_nexo: Nexo = null
## Ring slot (set by EnemyManager, consecutive) so enemies converging on a point spread out.
var slot: int = 0


func _ready() -> void:
	hurtbox.hurt.connect(_on_hurt)


## Call after add_child(): global_position needs the node in the tree.
func setup(start_position: Vector2) -> void:
	global_position = start_position


## Multipliers come from FloorManager (per-floor difficulty scaling); `p_type`
## (EnemyType) overrides the behaviour variant and stacks its own multipliers.
func configure(p_variant: Variant, p_zone_id: String, hp_multiplier: float = 1.0, damage_multiplier: float = 1.0, p_type: EnemyType = null) -> void:
	type = p_type
	variant = p_type.behavior as Variant if p_type else p_variant
	current_zone_id = p_zone_id
	if p_type:
		hp_multiplier *= p_type.hp_mult
		damage_multiplier *= p_type.damage_mult

	var cfg: Dictionary = VARIANT_CONFIG[variant]
	max_hp = maxi(1, roundi(int(cfg["hp"]) * hp_multiplier))
	current_hp = max_hp

	_apply_visual()

	ai_timer.wait_time = float(cfg.get("ai_interval", 1.5))
	ai_timer.one_shot = false
	ai_timer.timeout.connect(_on_ai_tick)
	ai_timer.start()

	var contact_damage := int(cfg.get("contact_damage", 1))
	if p_type:
		role = p_type.role
		aggro_range = p_type.aggro_range
		attack_range = p_type.attack_range
		nexus_damage = maxi(1, roundi(p_type.damage_vs_nexus * damage_multiplier)) if p_type.damage_vs_nexus > 0 else 0
		if p_type.damage_vs_heroes > 0:
			contact_damage = p_type.damage_vs_heroes
	hitbox.configure(maxi(1, roundi(contact_damage * damage_multiplier)), CONTACT_HIT_INTERVAL)

	attack_damage = maxi(1, roundi(int(cfg.get("damage_per_tick", DEFAULT_ATTACK_DAMAGE)) * damage_multiplier))
	attack_timer.wait_time = attack_speed
	attack_timer.one_shot = false
	attack_timer.timeout.connect(_perform_attack)


## Hurtbox hits only come from heroes (turrets call take_damage directly).
func _on_hurt(amount: int) -> void:
	_provoked_until_msec = Time.get_ticks_msec() + int(REACT_SEC * 1000)
	take_damage(amount)


func take_damage(amount: int) -> void:
	if not is_alive():
		return
	current_hp = maxi(current_hp - maxi(amount, 0), 0)
	if current_hp > 0:
		visual.play_hit()
	if current_hp <= 0:
		QuestLogger.info(QuestLogger.Category.ENEMY, "Enemy '%s' died in zone '%s'." % [Variant.keys()[variant], current_zone_id])
		died.emit(self)
		queue_free()


func is_alive() -> bool:
	return current_hp > 0


func apply_slow(duration: float) -> void:
	_slowed_until_msec = Time.get_ticks_msec() + int(duration * 1000)


func current_speed() -> float:
	var cfg: Dictionary = VARIANT_CONFIG[variant]
	var base_speed := float(cfg["speed"])
	if type:
		base_speed *= type.speed_mult
	return base_speed * 0.5 if Time.get_ticks_msec() < _slowed_until_msec else base_speed


## Sprite from the EnemyType; body, hurtbox and contact hitbox follow its drawn
## size (their shape resources are shared by every Enemy instance: duplicate).
## Hitbox damage/interval are untouched.
func _apply_visual() -> void:
	if type == null or type.sprite_frames == null:
		visual.visible = false
		return
	visual.setup(type.sprite_frames, type.visual_scale)
	if type.role == EnemyType.Role.RAIDER:
		_mark_as_raider()
	var radius := visual.fit_radius()
	var center := visual.body_center()
	for path in ["CollisionShape2D", "Hurtbox/CollisionShape2D", "Hitbox/CollisionShape2D"]:
		var collision := get_node(path) as CollisionShape2D
		var circle := collision.shape.duplicate() as CircleShape2D
		circle.radius = radius + (CONTACT_REACH if path.begins_with("Hitbox") else 0.0)
		collision.shape = circle
		collision.position = center


## Raiders: reddish tint + a red diamond over the head (hunters stay plain).
func _mark_as_raider() -> void:
	visual.modulate = RAIDER_TINT
	var marker := Polygon2D.new()
	marker.name = "RaiderMarker"
	marker.polygon = PackedVector2Array([Vector2(0, -6), Vector2(5, 0), Vector2(0, 6), Vector2(-5, 0)])
	marker.color = QuestPalette.BLOOD_LIGHT
	marker.position = visual.position + Vector2(0.0, -visual.body_size().y - 8.0)
	add_child(marker)


## First active module built in `room`, or null.
func scan_room_for_modules(room: RoomZone) -> Node2D:
	if room == null:
		return null
	for module in room.get_modules():
		if is_instance_valid(module) and module.is_active:
			return module
	return null


## Called by EnemyMoveAction each time the enemy reaches a zone center.
func on_zone_entered(zone_id: String) -> void:
	if current_state == State.ATTACKING or not is_alive():
		return
	var room_manager := ManagerLocator.get_room_manager()
	if room_manager == null or room_manager.get_zone_kind(zone_id) != "room" or _is_raiding():
		return
	var module := scan_room_for_modules(room_manager.get_zone_node(zone_id))
	if module == null:
		return
	target_module = module
	current_state = State.ATTACKING
	attack_timer.start()


func _perform_attack() -> void:
	if target_nexo != null:
		if not (_is_raiding() and _nexus_in_range()):
			_resume_moving()
			return
		target_nexo.take_damage(nexus_damage)
		return
	if not _target_is_valid():
		_resume_moving()
		return
	target_module.take_damage(attack_damage)
	if not _target_is_valid():
		_resume_moving()


func _target_is_valid() -> bool:
	return is_instance_valid(target_module) and (target_module as Module).is_active


func _resume_moving() -> void:
	attack_timer.stop()
	target_module = null
	target_nexo = null
	current_state = State.MOVING
	_on_ai_tick()


func _on_ai_tick() -> void:
	if _moving or current_state == State.ATTACKING or not is_alive():
		return
	var room_manager := ManagerLocator.get_room_manager()
	if room_manager == null:
		return
	# Modules in the current room (built later, or a second one after a kill)
	# are only scanned on arrival otherwise.
	on_zone_entered(current_zone_id)
	if current_state == State.ATTACKING:
		return
	_note_blocking_hero()
	if _try_attack_nexus():
		return

	var goal := _goal_zone(room_manager)
	_active_goal = goal
	await _pursue_zone(room_manager, goal, _goal_point(goal))
	if is_instance_valid(self):
		_try_attack_nexus()


## True when the zone this enemy wants changed since its current trip began;
## EnemyMoveAction checks it after each leg so a trip is re-planned mid-path.
func goal_changed() -> bool:
	var room_manager := ManagerLocator.get_room_manager()
	return room_manager != null and _goal_zone(room_manager) != _active_goal


## Zone this enemy heads for right now ("" = nowhere). HUNTER role: a hero
## inside aggro_range, else the closest hero's zone; a Sapper first hunts modules.
func _goal_zone(room_manager: RoomManager) -> String:
	if _is_raiding():
		return ManagerLocator.get_nexo().get_target_zone(room_manager)
	if variant == Variant.SAPPER:
		var module_zone := _find_zone_with_modules(room_manager)
		if module_zone != "":
			return module_zone
	var hero := _aggro_hero(room_manager)
	return hero.current_zone_id if hero else _player_zone(room_manager)


## Exact spot to close in on inside the goal zone (Vector2.INF = zone center).
func _goal_point(goal_zone: String) -> Vector2:
	if _is_raiding():
		return ManagerLocator.get_nexo().get_target_position()
	var room_manager := ManagerLocator.get_room_manager()
	var hero := _aggro_hero(room_manager) if room_manager else null
	if hero and hero.current_zone_id == goal_zone:
		return hero.global_position
	return Vector2.INF


## RAIDER role, a Nexo to hit and no hero provoking it: head for the Nexo and
## ignore heroes and modules. Otherwise it acts like a hunter.
func _is_raiding() -> bool:
	return role == EnemyType.Role.RAIDER and Time.get_ticks_msec() >= _provoked_until_msec and ManagerLocator.get_nexo() != null


## A hero within BLOCK_RANGE of a raider counts as provoking it.
func _note_blocking_hero() -> void:
	if role != EnemyType.Role.RAIDER:
		return
	for hero in ManagerLocator.get_heroes():
		if hero.stats.is_alive() and global_position.distance_to(hero.global_position) <= BLOCK_RANGE:
			_provoked_until_msec = Time.get_ticks_msec() + int(REACT_SEC * 1000)
			return


func _nexus_in_range() -> bool:
	var nexo := ManagerLocator.get_nexo()
	return nexo != null and nexo.is_alive() and global_position.distance_to(nexo.get_target_position()) <= attack_range


func _try_attack_nexus() -> bool:
	if not (_is_raiding() and nexus_damage > 0 and _nexus_in_range()):
		return false
	target_nexo = ManagerLocator.get_nexo()
	current_state = State.ATTACKING
	attack_timer.start()
	return true


## Closest living hero within aggro_range (px) that is reachable over the revealed graph.
func _aggro_hero(room_manager: RoomManager) -> Player:
	var best: Player = null
	var best_dist := aggro_range
	for hero in ManagerLocator.get_heroes():
		if not hero.stats.is_alive():
			continue
		var dist := global_position.distance_to(hero.global_position)
		if dist > best_dist:
			continue
		if hero.current_zone_id != current_zone_id and room_manager.find_zone_path(current_zone_id, hero.current_zone_id).size() < 2:
			continue
		best = hero
		best_dist = dist
	return best


## Zone of the closest hero (fewest zones over the revealed graph), so the
## hero selection never redirects enemies. "" if none is reachable.
func _player_zone(room_manager: RoomManager) -> String:
	var best := ""
	var best_len := 0
	for hero in ManagerLocator.get_heroes():
		if hero.current_zone_id == current_zone_id:
			return current_zone_id
		var path_len := room_manager.find_zone_path(current_zone_id, hero.current_zone_id).size()
		if path_len > 0 and (best == "" or path_len < best_len):
			best = hero.current_zone_id
			best_len = path_len
	return best


func _find_zone_with_modules(room_manager: RoomManager) -> String:
	for zone_id in room_manager.get_zone_ids():
		if room_manager.get_zone_kind(zone_id) != "room":
			continue
		if not room_manager.is_zone_revealed(zone_id):
			continue
		var group_id := room_manager.get_group_id(zone_id)
		if not room_manager.get_modules_in_group(group_id).is_empty():
			return zone_id
	return ""


## Glides to `target_zone_id`, then (if `point` is given and farther than
## attack_range) to a spot on a small ring around it so several enemies spread out.
func _pursue_zone(room_manager: RoomManager, target_zone_id: String, point: Vector2 = Vector2.INF) -> void:
	if target_zone_id == "":
		return
	var waypoints: Array[Vector2] = []
	var zone_ids: Array[String] = []
	if target_zone_id != current_zone_id:
		var path := room_manager.find_zone_path(current_zone_id, target_zone_id)
		if path.size() < 2:
			return
		for step_id in path.slice(1):
			waypoints.append(room_manager.get_center(step_id))
			zone_ids.append(step_id)
	if point != Vector2.INF and (not waypoints.is_empty() or global_position.distance_to(point) > attack_range):
		waypoints.append(point + _ring_offset())
		zone_ids.append(target_zone_id)
	if waypoints.is_empty():
		return

	_moving = true
	var action := EnemyMoveAction.new(self, waypoints, zone_ids)
	await action.execute()
	if not is_instance_valid(self):
		return
	_moving = false

	_check_trap_in_current_room(room_manager)


## Fixed per-enemy offset (8 consecutive slots) so enemies converging on one point don't stack.
func _ring_offset() -> Vector2:
	return Vector2.from_angle((slot % 8) * TAU / 8.0) * RING_RADIUS


func _check_trap_in_current_room(room_manager: RoomManager) -> void:
	var group_id := room_manager.get_group_id(current_zone_id)
	for module in room_manager.get_modules_in_group(group_id):
		if module.is_trap() and module.is_working():
			var cfg: Dictionary = Module.CATALOG[Module.ModuleType.TRAP]
			apply_slow(float(cfg["slow_duration"]))
			break
