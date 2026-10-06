extends Node2D
class_name Player

## Player: test-scene actor. Owns a CharacterStats component and a grid cell
## position. Moves freely — no turn/AP gating.

## Emitted by set_zone() (spawn and every arrival). Minimap listens.
signal zone_changed(zone_id: String)

const SELECTION_RING_COLOR := Color(0.95, 0.78, 0.35, 0.95)
## Vertical squash of the selection ring (a circle seen on the floor).
const SELECTION_RING_SQUASH := 0.4

@onready var stats: CharacterStats = $Stats
@onready var animated_sprite: CharacterVisual = $AnimatedSprite2D
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var hitbox: HitboxComponent = $Hitbox

var character_data: CharacterData = null
var current_zone_id: String = ""
var is_carrying_nexo: bool = false
## Sprite-only shift so heroes sharing a zone don't overlap (PartyConfig);
## position, zone logic and hit/hurtboxes stay on the zone center.
var sprite_offset: Vector2 = Vector2.ZERO

## grid_pos is the cell under the hero's world position — debug/logging only.
## Movement, door access and reachability all key off current_zone_id.
var grid_pos: Vector2i = Vector2i.ZERO

var _last_hp: int = -1
var abilities: HeroAbilities
var inventory: InventoryComponent


func configure(data: CharacterData) -> void:
	# Called before add_child(); @onready vars aren't valid yet, so just stash
	# the reference — actual visual application happens in _ready().
	character_data = data


func _ready() -> void:
	add_to_group("player")
	# Hitbox follows CharacterStats (base from CharacterData + in-run upgrades),
	# so wire it before register() re-applies upgrades.
	stats.attack_changed.connect(_on_attack_changed)
	stats.attack_range_changed.connect(_apply_attack_range)
	animated_sprite.position += sprite_offset
	if character_data:
		stats.hero_id = character_data.character_id
		stats.character_name = character_data.display_name
		stats.base_hp = character_data.base_hp
		stats.set_base_attack(character_data.attack_damage, character_data.attack_interval)
		_apply_attack_range(character_data.attack_range)
		stats.set_base_attack_range(character_data.attack_range)
		_apply_character_visuals(character_data)
		abilities = HeroAbilities.new()
		abilities.name = "Abilities"
		add_child(abilities)
		abilities.setup(self, character_data)
		inventory = InventoryComponent.new()
		inventory.name = "Inventory"
		add_child(inventory)
		inventory.setup(self)
	var player_stats := ManagerLocator.get_player_stats()
	if player_stats:
		player_stats.register(stats)
	hurtbox.hurt.connect(_on_hurt)
	# heroes-9: one target per tick (nearest in range); ranged heroes shoot it.
	hitbox.single_target = true
	if is_ranged():
		hitbox.deliver = _fire_projectile
	hitbox.hit_landed.connect(_on_attack_landed)
	_last_hp = stats.current_hp
	stats.hp_changed.connect(_on_hp_changed)
	stats.died.connect(queue_redraw)
	var selection := ManagerLocator.get_selection_manager()
	if selection:
		selection.selection_changed.connect(_on_selection_changed)


func _on_selection_changed(_selected_ids: Array[String]) -> void:
	queue_redraw()


## Ring under the feet while this hero is selected (drawn before the child
## sprite, so it sits behind it).
func _draw() -> void:
	if is_downed():  # red ring: downed, waiting for a revive
		draw_set_transform(animated_sprite.position, 0.0, Vector2(1.0, SELECTION_RING_SQUASH))
		draw_arc(Vector2.ZERO, animated_sprite.fit_radius() * 1.2, 0.0, TAU, 32, QuestPalette.BLOOD_LIGHT, 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var selection := ManagerLocator.get_selection_manager()
	if selection == null or not selection.is_selected(stats.hero_id) or not stats.is_alive():
		return
	draw_set_transform(animated_sprite.position, 0.0, Vector2(1.0, SELECTION_RING_SQUASH))
	draw_arc(Vector2.ZERO, animated_sprite.fit_radius() * 1.2, 0.0, TAU, 32, SELECTION_RING_COLOR, 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## HP dropping = a hit: blink white (heals and level-ups only raise HP).
## 0 HP = downed (heroes-9), back above 0 = revived.
func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	if _last_hp >= 0 and current_hp < _last_hp:
		animated_sprite.play_hit()
		var vfx := ManagerLocator.get_vfx_manager()
		if vfx:
			vfx.hurt(global_position, _last_hp - current_hp, max_hp)
	if current_hp <= 0 and _last_hp != 0:
		_set_downed(true)
	elif current_hp > 0 and _last_hp == 0:
		_set_downed(false)
	_last_hp = current_hp


## Downed: lies grey on the floor where it fell, no attacks, no hurtbox. A living
## ally in the same room can revive it (left click on it, PlayerStats.revive_hero).
func _set_downed(downed: bool) -> void:
	hitbox.set_active(not downed)
	hurtbox.set_deferred("monitorable", not downed)
	animated_sprite.rotation = PI * 0.5 if downed else 0.0
	animated_sprite.self_modulate = Color(0.45, 0.45, 0.5, 0.85) if downed else Color.WHITE
	queue_redraw()


func is_downed() -> bool:
	return stats != null and not stats.is_alive()


func is_ranged() -> bool:
	return character_data != null and character_data.attack_style == CharacterData.AttackStyle.RANGED


## CharacterData.move_speed_mult (Rogue fast, Tank slow).
func move_speed_mult() -> float:
	return character_data.move_speed_mult if character_data else 1.0


func _fire_projectile(target: HurtboxComponent, amount: int) -> void:
	var parent := get_parent() if get_parent() else self
	Projectile.fire(parent, to_global(animated_sprite.body_center()), target, hitbox, amount, character_data.projectile_speed, vfx_color())


## Palette of this hero's effects (CharacterData.vfx_color).
func vfx_color() -> Color:
	return character_data.vfx_color if character_data else Color.WHITE


## Auto-attack / burst landed on an enemy: slash + sparks (shake only if it is a strong hit).
func _on_attack_landed(target: HurtboxComponent, amount: int) -> void:
	var audio := ManagerLocator.get_audio()
	if audio:
		audio.play_sfx(&"hit")
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx == null or not is_instance_valid(target):
		return
	var enemy := target.get_parent() as Enemy
	if is_ranged():  # the projectile already flew there: sparks on impact, no slash arc
		vfx.play(&"hit_sparks", target.global_position, vfx_color())
		vfx.shake_if_strong(amount, enemy.max_hp if enemy else 1)
		return
	vfx.hit(global_position, target.global_position, vfx_color(), amount, enemy.max_hp if enemy else 1)


func _on_attack_changed(_damage: int, _interval: float) -> void:
	hitbox.configure(stats.effective_attack_damage(), stats.effective_attack_interval())


func _on_hurt(amount: int) -> void:
	if not stats.is_alive():
		return
	if abilities:
		amount = abilities.incoming_damage(amount)
	stats.take_damage(amount)
	animated_sprite.knockback(_away_from_nearest_enemy())
	QuestLogger.info(QuestLogger.Category.COMBAT, "Hero took %d damage (%d/%d HP)." % [amount, stats.current_hp, stats.max_hp])


## Unit vector from the closest enemy to this hero (knockback direction).
func _away_from_nearest_enemy() -> Vector2:
	var best := INF
	var dir := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null:
			continue
		var d := global_position.distance_squared_to(enemy.global_position)
		if d < best:
			best = d
			dir = enemy.global_position.direction_to(global_position)
	return dir


## The Hitbox circle is a shared sub-resource: duplicate before resizing.
func _apply_attack_range(radius: float) -> void:
	var shape := hitbox.get_node("CollisionShape2D") as CollisionShape2D
	var circle := shape.shape.duplicate() as CircleShape2D
	circle.radius = radius
	shape.shape = circle


func _apply_character_visuals(data: CharacterData) -> void:
	if data.sprite_frames == null or animated_sprite == null:
		return
	animated_sprite.setup(data.sprite_frames)
	# Hurtbox follows the drawn body (its shape resource is shared by every
	# Player instance, so duplicate). The attack Hitbox (AoE) is independent.
	var shape := hurtbox.get_node("CollisionShape2D") as CollisionShape2D
	var circle := shape.shape.duplicate() as CircleShape2D
	circle.radius = animated_sprite.fit_radius()
	shape.shape = circle
	shape.position = animated_sprite.body_center() - animated_sprite.position


func set_zone(zone_id: String, center: Vector2, tilemap: TileMapLayer) -> void:
	current_zone_id = zone_id
	global_position = center
	grid_pos = GridUtils.world_to_cell(tilemap, center)
	zone_changed.emit(zone_id)


func can_accept_input() -> bool:
	return stats != null and stats.is_alive()


func pick_up_nexo() -> void:
	is_carrying_nexo = true
