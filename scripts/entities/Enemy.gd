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


func _ready() -> void:
	hurtbox.hurt.connect(take_damage)


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
	var radius := visual.fit_radius()
	var center := visual.body_center()
	for path in ["CollisionShape2D", "Hurtbox/CollisionShape2D", "Hitbox/CollisionShape2D"]:
		var collision := get_node(path) as CollisionShape2D
		var circle := collision.shape.duplicate() as CircleShape2D
		circle.radius = radius + (CONTACT_REACH if path.begins_with("Hitbox") else 0.0)
		collision.shape = circle
		collision.position = center


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
	if room_manager == null or room_manager.get_zone_kind(zone_id) != "room":
		return
	var module := scan_room_for_modules(room_manager.get_zone_node(zone_id))
	if module == null:
		return
	target_module = module
	current_state = State.ATTACKING
	attack_timer.start()


func _perform_attack() -> void:
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

	match variant:
		Variant.SWARM:
			await _pursue_zone(room_manager, _player_zone(room_manager))
		Variant.SAPPER:
			await _sapper_tick(room_manager)
		Variant.HUNTER:
			for hero in ManagerLocator.get_heroes():
				if hero.is_carrying_nexo:
					await _pursue_zone(room_manager, hero.current_zone_id)
					break


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


func _sapper_tick(room_manager: RoomManager) -> void:
	var target_zone := _find_zone_with_modules(room_manager)
	if target_zone == "":
		target_zone = _player_zone(room_manager)
	await _pursue_zone(room_manager, target_zone)


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


func _pursue_zone(room_manager: RoomManager, target_zone_id: String) -> void:
	if target_zone_id == "" or target_zone_id == current_zone_id:
		return
	var path := room_manager.find_zone_path(current_zone_id, target_zone_id)
	if path.size() < 2:
		return

	var waypoints: Array[Vector2] = []
	var zone_ids: Array[String] = []
	for step_id in path.slice(1):
		waypoints.append(room_manager.get_center(step_id))
		zone_ids.append(step_id)

	_moving = true
	var action := EnemyMoveAction.new(self, waypoints, zone_ids)
	await action.execute()
	if not is_instance_valid(self):
		return
	_moving = false

	_check_trap_in_current_room(room_manager)


func _check_trap_in_current_room(room_manager: RoomManager) -> void:
	var group_id := room_manager.get_group_id(current_zone_id)
	for module in room_manager.get_modules_in_group(group_id):
		if module.is_trap() and module.is_working():
			var cfg: Dictionary = Module.CATALOG[Module.ModuleType.TRAP]
			apply_slow(float(cfg["slow_duration"]))
			break
