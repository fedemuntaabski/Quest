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


func configure(data: CharacterData) -> void:
	# Called before add_child(); @onready vars aren't valid yet, so just stash
	# the reference — actual visual application happens in _ready().
	character_data = data


func _ready() -> void:
	add_to_group("player")
	# Hitbox follows CharacterStats (base from CharacterData + in-run upgrades),
	# so wire it before register() re-applies upgrades.
	stats.attack_changed.connect(_on_attack_changed)
	animated_sprite.position += sprite_offset
	if character_data:
		stats.hero_id = character_data.character_id
		stats.character_name = character_data.display_name
		stats.base_hp = character_data.base_hp
		stats.set_base_attack(character_data.attack_damage, character_data.attack_interval)
		_apply_attack_range(character_data.attack_range)
		_apply_character_visuals(character_data)
		abilities = HeroAbilities.new()
		abilities.name = "Abilities"
		add_child(abilities)
		abilities.setup(self, character_data)
	var player_stats := ManagerLocator.get_player_stats()
	if player_stats:
		player_stats.register(stats)
	hurtbox.hurt.connect(_on_hurt)
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
	var selection := ManagerLocator.get_selection_manager()
	if selection == null or not selection.is_selected(stats.hero_id) or not stats.is_alive():
		return
	draw_set_transform(animated_sprite.position, 0.0, Vector2(1.0, SELECTION_RING_SQUASH))
	draw_arc(Vector2.ZERO, animated_sprite.fit_radius() * 1.2, 0.0, TAU, 32, SELECTION_RING_COLOR, 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## HP dropping = a hit: blink white (heals and level-ups only raise HP).
func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	if _last_hp >= 0 and current_hp < _last_hp:
		animated_sprite.play_hit()
		var vfx := ManagerLocator.get_vfx_manager()
		if vfx:
			vfx.hurt(global_position, _last_hp - current_hp, max_hp)
	_last_hp = current_hp


## Palette of this hero's effects (CharacterData.vfx_color).
func vfx_color() -> Color:
	return character_data.vfx_color if character_data else Color.WHITE


## Auto-attack / burst landed on an enemy: slash + sparks (shake only if it is a strong hit).
func _on_attack_landed(target: HurtboxComponent, amount: int) -> void:
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx == null or not is_instance_valid(target):
		return
	var enemy := target.get_parent() as Enemy
	vfx.hit(global_position, target.global_position, vfx_color(), amount, enemy.max_hp if enemy else 1)


func _on_attack_changed(_damage: int, interval: float) -> void:
	hitbox.configure(stats.effective_attack_damage(), interval)


func _on_hurt(amount: int) -> void:
	if not stats.is_alive():
		return
	if abilities:
		amount = abilities.incoming_damage(amount)
	stats.take_damage(amount)
	QuestLogger.info(QuestLogger.Category.COMBAT, "Hero took %d damage (%d/%d HP)." % [amount, stats.current_hp, stats.max_hp])


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
